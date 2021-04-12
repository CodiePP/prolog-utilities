/*   SWI-Prolog Interface to Postgresql
 *   Copyright (C) 1999-2020  Alexander Diemand
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
#include <string.h>
#include <ctype.h>

#include <SWI-Prolog.h>
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
foreign_t swi_pgsql_query_all (term_t dbx, term_t query, term_t list);
foreign_t swi_pgsql_query2 (term_t dbx, term_t query, term_t my_res, foreign_t handle);


/* macros */

#define PLException(msg,who) { term_t except = PL_new_term_ref();\
	PL_unify_term(except, PL_FUNCTOR_CHARS, "error", 2, PL_CHARS, msg, PL_CHARS, who);\
	return PL_raise_exception(except); }


/* Implementation */

install_t install()
{
	PL_register_foreign("pl_pgsql_connect", 1, swi_pgsql_connect1, 0);
	PL_register_foreign("pl_pgsql_connect", 6, swi_pgsql_connect2, 0);
	PL_register_foreign("pl_pgsql_disconnect", 1, swi_pgsql_disconnect, 0);
	PL_register_foreign("pl_pgsql_query", 2, swi_pgsql_query1, 0);
	PL_register_foreign("pl_pgsql_query_all", 3, swi_pgsql_query_all, 0);
	PL_register_foreign("pl_pgsql_query", 3, swi_pgsql_query2, PL_FA_NONDETERMINISTIC);
}

typedef struct {
	int valid;
	PGconn *dbx;
} pq_connection_encoded;


foreign_t swi_pgsql_connect1(term_t dbx)
{
  char    errmsg[256];
  char    *tenv;
  char 	*hostname;
  char	*dbname;
  char	*port;

  if (PL_term_type(dbx) != PL_VARIABLE)
  {
    PL_fail;
  }

  /* get PGHOST */
  tenv = getenv("PGHOST");
  if (!tenv)
  {
    snprintf(errmsg, 255, "PGSQL: pl_pgsql_connect/1 failed.\nNo environment variable $PGHOST\n");
    PLException(errmsg,"pl_pgsql_connect/1");
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
    snprintf (errmsg, 255, "PGSQL: pl_pgsql_connect/1 failed.\nNo environment variable $PGDATABASE\n");
    PLException(errmsg,"pl_pgsql_connect/1");
  }
  dbname = tenv;

  pq_connection_encoded *pgconn = malloc(sizeof(pq_connection_encoded));
  pgconn->dbx = PQsetdb(hostname, port, NULL, NULL, dbname);
  pgconn->valid = 1;

  /*
   * check to see that the backend connection was successfully made
   */
  if (PQstatus(pgconn->dbx) == CONNECTION_BAD)
  {
    snprintf (errmsg, 255, "PGSQL: Connection to database %s failed.\n%s", dbname, PQerrorMessage(pgconn->dbx));
    PQfinish(pgconn->dbx);
    pgconn->valid = 0;
    PLException(errmsg,"pl_pgsql_connect/1");
  }

  PL_unify_pointer(dbx, pgconn);
  PL_succeed;
}


foreign_t swi_pgsql_connect2(term_t p_hostname, term_t p_port, term_t p_user, term_t p_passwd, term_t p_dbname, term_t dbx) 
{
  char	errmsg[1024];
  char 	*hostname = NULL;
  char	*dbname = NULL;
  char 	*port = NULL;
  char 	*user = NULL;
  char 	*passwd = NULL;

  if (PL_term_type(dbx) != PL_VARIABLE)
  {
    PL_fail;
  }

  if (!PL_get_chars(p_hostname, &hostname, CVT_ATOM | CVT_STRING | CVT_LIST)) { PL_fail; }
  if (!PL_get_chars(p_port, &port, CVT_INTEGER)) { PL_fail; }
  if (!PL_get_chars(p_dbname, &dbname, CVT_ATOM | CVT_STRING | CVT_LIST)) { PL_fail; }
  if (PL_term_type(p_user) != PL_VARIABLE)
  {
    if (!PL_get_chars(p_user, &user, CVT_ATOM | CVT_STRING | CVT_LIST)) { PL_fail; }
  }
  if (PL_term_type(p_passwd) != PL_VARIABLE)
  {
    if (!PL_get_chars(p_passwd, &passwd, CVT_ATOM | CVT_STRING | CVT_LIST)) { PL_fail; }
  }

  pq_connection_encoded *pgconn = malloc(sizeof(pq_connection_encoded));
  pgconn->dbx = PQsetdbLogin(hostname, port, NULL, NULL, dbname, user, passwd);
  pgconn->valid = 1;

  /*
   * check to see that the backend connection was successfully made
   */
  if (PQstatus(pgconn->dbx) == CONNECTION_BAD)
  {
    sprintf (errmsg, "PGSQL: Connection to database %s failed.\n%s", dbname, PQerrorMessage(pgconn->dbx));
    PQfinish(pgconn->dbx);
    pgconn->valid = 0;
    PLException(errmsg,"pl_pgsql_connect/6");
  }

  PL_unify_pointer(dbx, pgconn);
  PL_succeed;
}


foreign_t swi_pgsql_disconnect (term_t dbx) 
{
  pq_connection_encoded *pgconn;

  PL_get_pointer(dbx, &pgconn);
  if (!pgconn || !pgconn->valid)
  {
    PL_fail;
  }

  if (PQstatus(pgconn->dbx) == CONNECTION_OK)
  {
    PQfinish(pgconn->dbx);
    pgconn->valid = 0;
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
    strncpy (errmsg, "PGSQL: connection type: ", 1023);
    strncat (errmsg, typereason, 1023);
    PQfinish(pgconn->dbx);
    pgconn->valid = 0;
    free(pgconn);
    PLException(errmsg,"pl_pgsql_disconnect/1");
  }
  free(pgconn);
  PL_succeed;
}
                

foreign_t swi_pgsql_query1 (term_t dbx, term_t query)
{
  char	errmsg[1024];
  PGresult *result;
  char	*qstr;
  unsigned long t_val;

  pq_connection_encoded *pgconn;

  PL_get_pointer(dbx, &pgconn);
  if (!pgconn || !pgconn->valid)
  {
    strncpy (errmsg, "PGSQL: connection NULL", 1023);
    PLException(errmsg,"pl_pgsql_query/2");
    PL_fail;
  }
  if (PQstatus(pgconn->dbx) != CONNECTION_OK)
  {
    strncpy (errmsg, "PGSQL: connection lost", 1023);
    PLException(errmsg,"pl_pgsql_query/2");
    PL_fail;
  }

  PL_get_chars(query, &qstr, CVT_ATOM | CVT_STRING | CVT_LIST);

  result = PQexec (pgconn->dbx, qstr);
  if (result || (PQresultStatus(result) == PGRES_COMMAND_OK)
      ||  (PQresultStatus(result) == PGRES_TUPLES_OK)) 
  {
    PQclear(result);
    PL_succeed;
  }
  snprintf(errmsg, 1023, "PGSQL: %s -> %s", PQresStatus(PQresultStatus(result)), PQresultErrorMessage(result));
  if (result) PQclear(result);
  PLException(errmsg,"pl_pgsql_query/2");
  PL_fail;
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
    tchar = PQgetvalue(result, idx, fnum);
    PL_unify_list(lst, val, lst);
    /* printf ("got: type %d  value %s\n", PQftype((*result),fnum), tchar);  */
    switch (PQftype(result, fnum)) {
        case INT2OID:
        case INT4OID:
        case OIDOID:
                PL_unify_integer(val, strtol(tchar,NULL,10));
                break;
        case FLOAT4OID:
        case FLOAT8OID:
        case CASHOID:
                PL_unify_float(val, strtod(tchar,NULL));
                break;
        default:
                if (strncmp(tchar,"NULL",4) == 0) {
                    PL_unify_nil(val);
                } else {
                    PL_unify_string_chars(val, tchar);
                }
                break;
    } /* switch field type */
  } /* for every field in the row */

  return PL_unify_nil(lst);
}

foreign_t swi_pgsql_query_all (term_t dbx, term_t query, term_t out_res) 
{
  char errmsg[256];

  if (! PL_is_variable(out_res))
  {
    strncpy (errmsg, "PGSQL: last argument should be variable output!", 1023);
    PLException(errmsg,"pl_pgsql_query/3");
  }

  /* fprintf(stderr, "Conn: %lx Query: %s\n", my_pgsql->value.l,query); */

  PGresult *pqres;
  char *qstr;

  pq_connection_encoded *pgconn;

  PL_get_pointer(dbx, &pgconn);
  if (!pgconn || !pgconn->valid) { PL_fail; }

  PL_get_chars(query, &qstr, CVT_ATOM | CVT_STRING | CVT_LIST);

  /* send query and receive result */
  pqres = PQexec (pgconn->dbx, qstr);
  if ((PQresultStatus(pqres) != PGRES_COMMAND_OK) &&
      (PQresultStatus(pqres) != PGRES_TUPLES_OK))
  {
    snprintf(errmsg, 1023, "PGSQL: %s -> %s", PQresStatus(PQresultStatus(pqres)), PQresultErrorMessage(pqres));
    PQclear(pqres);
    PLException(errmsg,"pl_pgsql_query_all/3");
    PL_fail;
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
    PL_unify_list(lst, row, lst);
    unify_result_row(pqres, nfields, rowidx, row);
  }

  PQclear(pqres);
  PL_succeed;
}
    

foreign_t swi_pgsql_query2 (term_t dbx, term_t query, term_t my_res, foreign_t handle) 
{
  pq_result_encoded *result;
  char errmsg[1024];

  if (! PL_is_variable(my_res))
  {
    strncpy (errmsg, "PGSQL: last argument should be variable output!", 1023);
    PLException(errmsg,"pl_pgsql_query/3");
  }

  /* fprintf(stderr, "Conn: %lx Query: %s\n", my_pgsql->value.l,query); */

  switch (PL_foreign_control(handle))
  { 
    case PL_FIRST_CALL:
      {
        PGresult   *pqres;
        char	*qstr;
        unsigned long t_val;

        pq_connection_encoded *pgconn;

        PL_get_pointer(dbx, &pgconn);
        if (!pgconn || !pgconn->valid)
        {
          PL_fail;
        }

        PL_get_chars(query, &qstr, CVT_ATOM | CVT_STRING | CVT_LIST);

        /* send query and receive result */
        pqres = PQexec (pgconn->dbx, qstr);
        if ((PQresultStatus(pqres) != PGRES_COMMAND_OK)
            && (PQresultStatus(pqres) != PGRES_TUPLES_OK)) {

          snprintf(errmsg, 1023, "PGSQL: %s -> %s", PQresStatus(PQresultStatus(pqres)), PQresultErrorMessage(pqres));
          PQclear(pqres);
          PLException(errmsg,"pl_pgsql_query/3");
          PL_fail;
        }
        if (PQntuples(pqres) <= 0)
        {
          PQclear(pqres);
          PL_fail;
        }
        result = malloc(sizeof(pq_result_encoded));
        result->result = pqres;
        result->nrows =  PQntuples(pqres);
        result->nfields = PQnfields(pqres);
        result->atrow = 0;
        break;
      }
    case PL_REDO:
      result = PL_foreign_context_address(handle);
      break;
    case PL_CUTTED:
      result = PL_foreign_context_address(handle);
      PQclear(result->result);
      free(result);
      PL_succeed;
      break;
  }

  /* fprintf(stderr, "Result rows: %d fields: %d\n", nrows, nfields); */

  unify_result_row(result->result, result->nfields, result->atrow, my_res);

  result->atrow++;

  if (result->atrow >= result->nrows)
  {
    PQclear(result->result);
    free(result);
    PL_succeed;		// stop here
  }


  if (PL_foreign_control(handle) != PL_CUTTED)
  {
    PL_retry_address(result);
  }
  PL_succeed;
}

