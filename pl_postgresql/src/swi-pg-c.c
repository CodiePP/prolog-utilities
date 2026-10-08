/*   SWI-Prolog Interface to Postgresql
 *   Copyright (C) 1999-2026  Alexander Diemand
 * 
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *   
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *   
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include <SWI-Stream.h>
#include <SWI-Prolog.h>

#if PLVERSION < 80000
#error "needs SWI-Prolog >= 8.0"
#endif

/* older names of BUF_STACK (< 8.5) and PL_PRUNED (< 8.3) */
#ifndef BUF_STACK
#define BUF_STACK BUF_RING
#endif
#ifndef PL_PRUNED
#define PL_PRUNED PL_CUTTED
#endif
#include <libpq-fe.h>


/* copied from the python interface, should be defined in a pgsql header instead!! */

#define INT2OID         21
#define INT4OID         23
#define OIDOID          26
#define FLOAT4OID       700
#define FLOAT8OID       701
#define CASHOID         790


/* Prototypes */

foreign_t swi_pgsql_connect1(term_t dbx);
foreign_t swi_pgsql_connect2(term_t host, term_t port, term_t user, term_t passwd, term_t dbname, term_t dbx);
foreign_t swi_pgsql_disconnect (term_t dbx);
foreign_t swi_pgsql_query1 (term_t dbx, term_t query);
foreign_t swi_pgsql_exec (term_t dbx, term_t query, term_t params);
foreign_t swi_pgsql_query_all (term_t dbx, term_t query, term_t list);
foreign_t swi_pgsql_query_all_params (term_t dbx, term_t query, term_t params, term_t list);
foreign_t swi_pgsql_query2 (term_t dbx, term_t query, term_t my_res, control_t handle);


/* macros */

/* raises error(Formal(Message), context(Name/Arity, _)); who is "Name/Arity".
 * Trailing white space (libpq/regerror messages end with a newline) is removed. */
static int raise_error(const char *formal, const char *msg, const char *who)
{
	char name[64];
	char text[1024];
	const char *slash = strrchr(who, '/');
	size_t n = slash ? (size_t)(slash - who) : strlen(who);
	term_t ex = PL_new_term_ref();

	if (n >= sizeof(name)) {
		n = sizeof(name) - 1;
	}
	memcpy(name, who, n);
	name[n] = '\0';
	snprintf(text, sizeof(text), "%s", msg);
	for (n = strlen(text); n > 0 && (text[n-1] == '\n' || text[n-1] == '\r' || text[n-1] == ' '); n--) {
		text[n-1] = '\0';
	}
	msg = text;
	if (!PL_unify_term(ex,
	                   PL_FUNCTOR_CHARS, "error", 2,
	                     PL_FUNCTOR_CHARS, formal, 1,
	                       PL_CHARS, msg,
	                     PL_FUNCTOR_CHARS, "context", 2,
	                       PL_FUNCTOR_CHARS, "/", 2,
	                         PL_CHARS, name,
	                         PL_INT, slash ? atoi(slash + 1) : 0,
	                       PL_VARIABLE)) {
		return FALSE;
	}
	return PL_raise_exception(ex);
}

#define PLException(formal, msg, who) return raise_error(formal, msg, who)


/* Connections
 *
 * A connection is handed to Prolog as a blob of type pgsql_connection that
 * holds a pointer to a pq_connection_encoded. pl_pgsql_disconnect/1 closes
 * the libpq connection and sets dbx to NULL, but the structure itself is only
 * freed when the blob is garbage collected. A handle used after disconnect is
 * therefore detected instead of dereferencing freed memory, and arbitrary
 * terms (e.g. integers) are rejected as handles.
 */

typedef struct {
	PGconn *dbx;		/* NULL once disconnected */
} pq_connection_encoded;

static int release_pgsql_connection(atom_t a)
{
	pq_connection_encoded *pgconn = *(pq_connection_encoded **)PL_blob_data(a, NULL, NULL);

	if (pgconn->dbx)
	{
		PQfinish(pgconn->dbx);
	}
	free(pgconn);
	return TRUE;
}

static int write_pgsql_connection(IOSTREAM *s, atom_t a, int flags)
{
	pq_connection_encoded *pgconn = *(pq_connection_encoded **)PL_blob_data(a, NULL, NULL);

	(void)flags;
	Sfprintf(s, "<pgsql_connection>(%p%s)", (void *)pgconn, pgconn->dbx ? "" : ",closed");
	return TRUE;
}

static PL_blob_t pgsql_connection_blob =
{
	.magic   = PL_BLOB_MAGIC,
	.flags   = PL_BLOB_UNIQUE,
	.name    = "pgsql_connection",
	.release = release_pgsql_connection,
	.write   = write_pgsql_connection,
};

/* wraps a freshly opened libpq connection in a blob and unifies it with dbx */
static int unify_connection(term_t dbx, PGconn *conn)
{
	pq_connection_encoded *pgconn = malloc(sizeof(pq_connection_encoded));

	if (!pgconn)
	{
		PQfinish(conn);
		return PL_resource_error("memory");
	}
	pgconn->dbx = conn;
	/* if unification fails, garbage collection of the blob closes the connection */
	return PL_unify_blob(dbx, &pgconn, sizeof(pgconn), &pgsql_connection_blob);
}

/* returns TRUE and sets pgconn if dbx is a connection handle (open or closed) */
static int get_connection(term_t dbx, pq_connection_encoded **pgconn)
{
	void *data;
	PL_blob_t *type;

	if (!PL_get_blob(dbx, &data, NULL, &type) || type != &pgsql_connection_blob)
	{
		return FALSE;
	}
	*pgconn = *(pq_connection_encoded **)data;
	return TRUE;
}

/* like get_connection/2, but raises an exception unless dbx is an open connection */
static int get_open_connection(term_t dbx, pq_connection_encoded **pgconn, const char *who)
{
	if (!get_connection(dbx, pgconn))
	{
		return PL_type_error("pgsql_connection", dbx);
	}
	if (!(*pgconn)->dbx)
	{
		return PL_existence_error("pgsql_connection", dbx);	/* disconnected */
	}
	if (PQstatus((*pgconn)->dbx) != CONNECTION_OK)
	{
		PLException("pgsql_error", "connection lost", (char *)who);
	}
	return TRUE;
}


/* Implementation */

install_t install()
{
	PL_register_foreign("pl_pgsql_connect", 1, swi_pgsql_connect1, 0);
	PL_register_foreign("pl_pgsql_connect", 6, swi_pgsql_connect2, 0);
	PL_register_foreign("pl_pgsql_disconnect", 1, swi_pgsql_disconnect, 0);
	PL_register_foreign("pl_pgsql_query", 2, swi_pgsql_query1, 0);
	PL_register_foreign("pl_pgsql_exec", 3, swi_pgsql_exec, 0);
	PL_register_foreign("pl_pgsql_query_all", 3, swi_pgsql_query_all, 0);
	PL_register_foreign("pl_pgsql_query_all", 4, swi_pgsql_query_all_params, 0);
	PL_register_foreign("pl_pgsql_query", 3, swi_pgsql_query2, PL_FA_NONDETERMINISTIC);
}


foreign_t swi_pgsql_connect1(term_t dbx)
{
  char    errmsg[1024];
  char    *tenv;
  char 	*hostname;
  char	*dbname;
  char	*port;
  PGconn  *conn;

  if (PL_term_type(dbx) != PL_VARIABLE)
  {
    PL_fail;
  }

  /* get PGHOST */
  tenv = getenv("PGHOST");
  if (!tenv)
  {
    snprintf(errmsg, sizeof(errmsg), "environment variable PGHOST is not set");
    PLException("pgsql_error", errmsg,"pl_pgsql_connect/1");
  }
  hostname = tenv;

  /* get PGPORT */
  tenv = getenv("PGPORT");
  if (tenv)
  {
    port = tenv;
  } else {
    port = "5432";
  }

  /* get PGDATABASE */
  tenv = getenv("PGDATABASE");
  if (!tenv)
  {
    snprintf (errmsg, sizeof(errmsg), "environment variable PGDATABASE is not set");
    PLException("pgsql_error", errmsg,"pl_pgsql_connect/1");
  }
  dbname = tenv;

  conn = PQsetdb(hostname, port, NULL, NULL, dbname);
  if (!conn)
  {
    return PL_resource_error("memory");
  }

  /*
   * check to see that the backend connection was successfully made
   */
  if (PQstatus(conn) == CONNECTION_BAD)
  {
    snprintf (errmsg, sizeof(errmsg), "connection to database %s failed: %s", dbname, PQerrorMessage(conn));
    PQfinish(conn);
    PLException("pgsql_error", errmsg,"pl_pgsql_connect/1");
  }

  return unify_connection(dbx, conn);
}


foreign_t swi_pgsql_connect2(term_t p_hostname, term_t p_port, term_t p_user, term_t p_passwd, term_t p_dbname, term_t dbx) 
{
  char	errmsg[1024];
  char 	*hostname = NULL;
  char	*dbname = NULL;
  char 	*port = NULL;
  char 	*user = NULL;
  char 	*passwd = NULL;
  PGconn *conn;

  if (PL_term_type(dbx) != PL_VARIABLE)
  {
    PL_fail;
  }

  /* BUF_STACK: the strings must stay valid while the others are converted */
  if (!PL_get_chars(p_hostname, &hostname, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_STACK)) { PL_fail; }
  if (!PL_get_chars(p_port, &port, CVT_INTEGER | BUF_STACK)) { PL_fail; }
  if (!PL_get_chars(p_dbname, &dbname, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_STACK)) { PL_fail; }
  if (PL_term_type(p_user) != PL_VARIABLE)
  {
    if (!PL_get_chars(p_user, &user, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_STACK)) { PL_fail; }
  }
  if (PL_term_type(p_passwd) != PL_VARIABLE)
  {
    if (!PL_get_chars(p_passwd, &passwd, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_STACK)) { PL_fail; }
  }

  conn = PQsetdbLogin(hostname, port, NULL, NULL, dbname, user, passwd);
  if (!conn)
  {
    return PL_resource_error("memory");
  }

  /*
   * check to see that the backend connection was successfully made
   */
  if (PQstatus(conn) == CONNECTION_BAD)
  {
    snprintf (errmsg, sizeof(errmsg), "connection to database %s failed: %s", dbname, PQerrorMessage(conn));
    PQfinish(conn);
    PLException("pgsql_error", errmsg,"pl_pgsql_connect/6");
  }

  return unify_connection(dbx, conn);
}


foreign_t swi_pgsql_disconnect (term_t dbx) 
{
  pq_connection_encoded *pgconn = NULL;

  if (!get_connection(dbx, &pgconn))
  {
    return PL_type_error("pgsql_connection", dbx);
  }
  if (!pgconn->dbx)
  {
    PL_fail;	/* already disconnected */
  }

  if (PQstatus(pgconn->dbx) == CONNECTION_OK)
  {
    PQfinish(pgconn->dbx);
    pgconn->dbx = NULL;
  } else {
    char *typereason;
    char errmsg[1024];
    ConnStatusType connstat = PQstatus(pgconn->dbx);
    switch (connstat) {
      case CONNECTION_SETENV:
        typereason="CONNECTION_SETENV";
        break;
      case CONNECTION_AUTH_OK:
        typereason="CONNECTION_AUTH_OK";
        break;
      case CONNECTION_AWAITING_RESPONSE:
        typereason="CONNECTION_AWAITING_RESPONSE";
        break;
      case CONNECTION_MADE:
        typereason="CONNECTION_MADE";
        break;
      case CONNECTION_STARTED:
        typereason="CONNECTION_STARTED";
        break;
      case CONNECTION_BAD:
        typereason="CONNECTION_BAD";
        break;
      case CONNECTION_OK:
        typereason="CONNECTION_OK";
        break;
      default:
        typereason="unknown Connection type reason.";
        break;
    };
    snprintf (errmsg, sizeof(errmsg), "bad connection status: %s", typereason);
    PQfinish(pgconn->dbx);
    pgconn->dbx = NULL;
    PLException("pgsql_error", errmsg,"pl_pgsql_disconnect/1");
  }
  PL_succeed;
}


/* Queries */

/* frees the parameter values collected by get_params() */
static void free_params(char **values, size_t nparams)
{
  size_t i;

  if (!values)
  {
    return;
  }
  for (i = 0; i < nparams; i++)
  {
    if (values[i])
    {
      PL_free(values[i]);
    }
  }
  free(values);
}

/* converts the Prolog list params to an array of strings for PQexecParams;
 * [] becomes SQL NULL. On error, an exception is raised and FALSE returned. */
static int get_params(term_t params, size_t *nparams, char ***values)
{
  term_t lst = PL_copy_term_ref(params);
  term_t head = PL_new_term_ref();
  size_t len, i;

  *nparams = 0;
  *values = NULL;
  if (PL_skip_list(params, 0, &len) != PL_LIST)
  {
    return PL_type_error("list", params);
  }
  if (len == 0)
  {
    return TRUE;
  }
  if (len > 65535)	/* limit of the PostgreSQL protocol */
  {
    return PL_domain_error("pgsql_parameter_list", params);
  }

  *values = calloc(len, sizeof(char *));
  if (!*values)
  {
    return PL_resource_error("memory");
  }
  for (i = 0; PL_get_list(lst, head, lst); i++)
  {
    if (PL_get_nil(head))
    {
      continue;		/* SQL NULL */
    }
    if (!PL_get_chars(head, &(*values)[i], CVT_ATOMIC | CVT_LIST | BUF_MALLOC))
    {
      free_params(*values, len);
      *values = NULL;
      return PL_type_error("pgsql_parameter", head);
    }
  }
  *nparams = len;
  return TRUE;
}

/* sends query (with the values in the list params, unless params is 0) and
 * returns the result in res if its status is COMMAND_OK or TUPLES_OK.
 * Otherwise an exception is raised and FALSE returned. */
static int exec_query(term_t dbx, term_t query, term_t params, const char *who, PGresult **res)
{
  char	errmsg[1024];
  char	*qstr;
  char	**values = NULL;
  size_t nparams = 0;
  PGresult *result;
  ExecStatusType status;
  pq_connection_encoded *pgconn = NULL;

  *res = NULL;
  if (!get_open_connection(dbx, &pgconn, who))
  {
    return FALSE;
  }
  if (params && !get_params(params, &nparams, &values))
  {
    return FALSE;
  }
  /* converted last: the discardable buffer is reused by the next conversion */
  if (!PL_get_chars(query, &qstr, CVT_ATOM | CVT_STRING | CVT_LIST))
  {
    free_params(values, nparams);
    return PL_type_error("text", query);
  }

  if (params)
  {
    result = PQexecParams(pgconn->dbx, qstr, (int)nparams, NULL,
                          (const char * const *)values, NULL, NULL, 0);
  } else {
    result = PQexec(pgconn->dbx, qstr);
  }
  free_params(values, nparams);

  if (!result)
  {
    snprintf(errmsg, sizeof(errmsg), "%s", PQerrorMessage(pgconn->dbx));
    PLException("pgsql_error", errmsg, (char *)who);
  }
  status = PQresultStatus(result);
  if ((status != PGRES_COMMAND_OK) && (status != PGRES_TUPLES_OK))
  {
    snprintf(errmsg, sizeof(errmsg), "%s: %s", PQresStatus(status), PQresultErrorMessage(result));
    PQclear(result);
    PLException("pgsql_error", errmsg, (char *)who);
  }
  *res = result;
  return TRUE;
}


foreign_t swi_pgsql_query1 (term_t dbx, term_t query)
{
  PGresult *result;

  if (!exec_query(dbx, query, 0, "pl_pgsql_query/2", &result))
  {
    return FALSE;
  }
  PQclear(result);
  PL_succeed;
}

foreign_t swi_pgsql_exec (term_t dbx, term_t query, term_t params)
{
  PGresult *result;

  if (!exec_query(dbx, query, params, "pl_pgsql_exec/3", &result))
  {
    return FALSE;
  }
  PQclear(result);
  PL_succeed;
}

typedef struct {
	int nfields;
	int nrows;
	int atrow;
	PGresult *result;
} pq_result_encoded;

int unify_result_row(PGresult *result, int nfields, int idx, term_t out_row)
{
	term_t val = PL_new_term_ref();
	term_t lst = PL_copy_term_ref(out_row);

	/* copy single row to list */
  int fnum;
  for (fnum = 0; fnum < nfields; fnum++)
  {
    char *tchar;
    if (!PL_unify_list(lst, val, lst))
    {
      return FALSE;
    }
    if (PQgetisnull(result, idx, fnum))
    {
      if (!PL_unify_nil(val)) { return FALSE; }
      continue;
    }
    tchar = PQgetvalue(result, idx, fnum);
    /* printf ("got: type %d  value %s\n", PQftype((*result),fnum), tchar);  */
    switch (PQftype(result, fnum)) {
        case INT2OID:
        case INT4OID:
        case OIDOID:
                if (!PL_unify_integer(val, strtol(tchar,NULL,10))) { return FALSE; }
                break;
        case FLOAT4OID:
        case FLOAT8OID:
        case CASHOID:
                if (!PL_unify_float(val, strtod(tchar,NULL))) { return FALSE; }
                break;
        default:
                if (!PL_unify_string_chars(val, tchar)) { return FALSE; }
                break;
    } /* switch field type */
  } /* for every field in the row */

  return PL_unify_nil(lst);
}

static int query_all(term_t dbx, term_t query, term_t params, term_t out_res, const char *who)
{
  PGresult *pqres;

  if (! PL_is_variable(out_res))
  {
    return PL_uninstantiation_error(out_res);
  }

  /* send query and receive result */
  if (!exec_query(dbx, query, params, who, &pqres))
  {
    return FALSE;
  }

  int nrows = PQntuples(pqres);
  if (nrows <= 0) {
    PQclear(pqres);
    PL_fail;
  }
  int nfields = PQnfields(pqres);

  //fprintf(stderr, "Result rows: %d fields: %d\n", nrows, nfields);

  term_t row = PL_new_term_ref();
  term_t lst = PL_copy_term_ref(out_res);

  int rowidx;
  for (rowidx = 0; rowidx < nrows; rowidx++)
  {
    if (!PL_unify_list(lst, row, lst) ||
        !unify_result_row(pqres, nfields, rowidx, row))
    {
      PQclear(pqres);
      return FALSE;
    }
  }

  PQclear(pqres);
  return PL_unify_nil(lst);
}

foreign_t swi_pgsql_query_all (term_t dbx, term_t query, term_t out_res) 
{
  return query_all(dbx, query, 0, out_res, "pl_pgsql_query_all/3");
}

foreign_t swi_pgsql_query_all_params (term_t dbx, term_t query, term_t params, term_t out_res) 
{
  return query_all(dbx, query, params, out_res, "pl_pgsql_query_all/4");
}
    

foreign_t swi_pgsql_query2 (term_t dbx, term_t query, term_t my_res, control_t handle) 
{
  pq_result_encoded *result;

  switch (PL_foreign_control(handle))
  { 
    case PL_FIRST_CALL:
      {
        PGresult   *pqres;

        if (! PL_is_variable(my_res))
        {
          return PL_uninstantiation_error(my_res);
        }

        /* send query and receive result */
        if (!exec_query(dbx, query, 0, "pl_pgsql_query/3", &pqres))
        {
          return FALSE;
        }
        if (PQntuples(pqres) <= 0)
        {
          PQclear(pqres);
          PL_fail;
        }
        result = malloc(sizeof(pq_result_encoded));
        if (!result)
        {
          PQclear(pqres);
          return PL_resource_error("memory");
        }
        result->result = pqres;
        result->nrows =  PQntuples(pqres);
        result->nfields = PQnfields(pqres);
        result->atrow = 0;
        break;
      }
    case PL_REDO:
      result = PL_foreign_context_address(handle);
      break;
    case PL_PRUNED:
    default:
      result = PL_foreign_context_address(handle);
      PQclear(result->result);
      free(result);
      PL_succeed;
  }

  /* fprintf(stderr, "Result rows: %d fields: %d\n", nrows, nfields); */

  if (!unify_result_row(result->result, result->nfields, result->atrow, my_res))
  {
    PQclear(result->result);
    free(result);
    return FALSE;
  }

  result->atrow++;

  if (result->atrow >= result->nrows)
  {
    PQclear(result->result);
    free(result);
    PL_succeed;		// stop here
  }

  PL_retry_address(result);
}
