/*   Prolog Interface to PostgreSQL -- GNU Prolog bridge
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

#include "gprolog.h"

#if !defined(__GPROLOG_VERSION__) || __GPROLOG_VERSION__ < 10400
#error "needs GNU Prolog >= 1.4.0"
#endif
#include "pgsql_core.h"

/*
 * GNU Prolog has no equivalent of a SWI-Prolog blob, so a connection is not
 * an opaque pointer wrapped by the engine: it is a small integer, the
 * 1-based index of its slot in gp_pgsql_table below. The table only grows
 * (a handle is never reused for a different PGconn), so a stale handle is
 * always either in range with a NULL slot (existence_error, disconnected)
 * or out of range / not even an integer (type_error, never issued). Unlike
 * the SWI-Prolog blob, a connection that is never disconnected is only
 * closed when the process exits: there is no finalizer to rely on here, so
 * always disconnect explicitly (e.g. from a cleanup handler).
 *
 * Free-form text (query results, error-less paths) is always built with
 * Pl_Mk_Codes/Pl_Un_Codes_Check (a code list), never Pl_Mk_Atom or
 * Pl_Mk_String (which, depending on the double_quotes flag, may also
 * intern an atom): a result row read back from a large table must not
 * grow GNU Prolog's fixed-size atom table.
 */

static PGconn **gp_pgsql_table = NULL;
static int gp_pgsql_table_len = 0;
static int gp_pgsql_table_cap = 0;

/* allocates a new handle for conn; returns the 1-based handle, or 0 on OOM */
static long gp_pgsql_table_alloc(PGconn *conn)
{
  if (gp_pgsql_table_len == gp_pgsql_table_cap)
  {
    int newcap = gp_pgsql_table_cap ? gp_pgsql_table_cap * 2 : 16;
    PGconn **nt = (PGconn **)realloc(gp_pgsql_table, (size_t)newcap * sizeof(PGconn *));
    if (!nt)
    {
      return 0;
    }
    gp_pgsql_table = nt;
    gp_pgsql_table_cap = newcap;
  }
  gp_pgsql_table[gp_pgsql_table_len] = conn;
  gp_pgsql_table_len++;
  return gp_pgsql_table_len;
}


/* Errors */

/* error(pgsql_error(Message), context(Name/Arity, _)); mirrors the SWI
 * bridge so prolog:error_message//1 in pgsql.pl renders both the same */
static PlBool gp_pgsql_error(const char *msg, const char *who, int arity)
{
  PlTerm f[1], pi[2], ctx[2], err[2];

  f[0] = Pl_Mk_Atom(Pl_Create_Allocate_Atom((char *)msg));
  pi[0] = Pl_Mk_Atom(Pl_Create_Atom((char *)who));
  pi[1] = Pl_Mk_Integer(arity);
  ctx[0] = Pl_Mk_Compound(Pl_Create_Atom("/"), 2, pi);
  ctx[1] = Pl_Mk_Variable();
  err[0] = Pl_Mk_Compound(Pl_Create_Atom("pgsql_error"), 1, f);
  err[1] = Pl_Mk_Compound(Pl_Create_Atom("context"), 2, ctx);
  Pl_Throw(Pl_Mk_Compound(Pl_Create_Atom("error"), 2, err));
  return PL_FALSE;
}

/* error(uninstantiation_error(Term), _); GNU Prolog has no Pl_Err_* helper
 * for this (ISO does not define it either; it mirrors SWI-Prolog's
 * PL_uninstantiation_error, used by the SWI bridge for the same check) */
static PlBool gp_pgsql_uninstantiation_error(PlTerm culprit)
{
  PlTerm f[1], err[2];

  f[0] = culprit;
  err[0] = Pl_Mk_Compound(Pl_Create_Atom("uninstantiation_error"), 1, f);
  err[1] = Pl_Mk_Variable();
  Pl_Throw(Pl_Mk_Compound(Pl_Create_Atom("error"), 2, err));
  return PL_FALSE;
}


/* Connections */

/* returns TRUE and sets *out if t is a handle (open or closed) issued by
 * pl_pgsql_connect; raises type_error(pgsql_connection, t) otherwise */
static int gp_pgsql_get_conn(PlTerm t, PGconn **out)
{
  PlLong idx;

  if (!Pl_Builtin_Integer(t))
  {
    Pl_Err_Type(Pl_Create_Atom("pgsql_connection"), t);
    return FALSE;
  }
  idx = Pl_Rd_Integer_Check(t);
  if (idx < 1 || idx > gp_pgsql_table_len)
  {
    Pl_Err_Type(Pl_Create_Atom("pgsql_connection"), t);
    return FALSE;
  }
  *out = gp_pgsql_table[idx - 1];
  return TRUE;
}

/* like gp_pgsql_get_conn/2, but raises existence_error for a disconnected
 * handle, and an error(pgsql_error(_),_) if the connection has gone bad */
static int gp_pgsql_get_open_conn(PlTerm t, PGconn **out)
{
  if (!gp_pgsql_get_conn(t, out))
  {
    return FALSE;
  }
  if (!*out)
  {
    Pl_Err_Existence(Pl_Create_Atom("pgsql_connection"), t);
    return FALSE;
  }
  return TRUE;
}


/* Text
 *
 * Pl_Rd_String_Check/Pl_Rd_Codes_Check and friends write into the single
 * global buffer pl_glob_buff shared by the whole engine: the pointer they
 * return is only valid until the next such call. Several of these strings
 * (connection parameters, query parameters) must stay alive at the same
 * time, so each is copied out into its own malloc'd buffer immediately.
 */

/* the text of an atom, integer, float or code list, as a newly malloc'd
 * NUL-terminated buffer the caller must free; NULL (no exception raised)
 * for anything else, so the caller can pick the right error */
static char *gp_pgsql_text_owned(PlTerm t)
{
  if (Pl_Builtin_Atom(t))
  {
    char *name = Pl_Atom_Name(Pl_Rd_Atom_Check(t));
    char *out = (char *)malloc(strlen(name) + 1);
    if (out) { strcpy(out, name); }
    return out;
  }
  if (Pl_Builtin_Integer(t))
  {
    char buf[32];
    snprintf(buf, sizeof(buf), "%ld", (long)Pl_Rd_Integer_Check(t));
    return strdup(buf);
  }
  if (Pl_Builtin_Float(t))
  {
    char buf[64];
    snprintf(buf, sizeof(buf), "%.17g", Pl_Rd_Float_Check(t));
    return strdup(buf);
  }
  {
    int len = Pl_List_Length(t);
    char *out;

    if (len < 0)
    {
      return NULL;
    }
    out = (char *)malloc((size_t)len + 1);
    if (!out)
    {
      return NULL;
    }
    if (len > 0)
    {
      Pl_Rd_Codes_Str_Check(t, out);
    } else {
      out[0] = '\0';
    }
    return out;
  }
}


/* Parameters */

#define GP_PGSQL_MAX_PARAMS 65535

typedef struct {
  char **values;	/* NULL entry: SQL NULL */
  int n;
} gp_pgsql_params;

static void gp_pgsql_params_free(gp_pgsql_params *p)
{
  int i;

  if (!p->values)
  {
    return;
  }
  for (i = 0; i < p->n; i++)
  {
    free(p->values[i]);
  }
  free(p->values);
  p->values = NULL;
  p->n = 0;
}

/* converts the Prolog list params to an array of strings for PQexecParams;
 * [] becomes SQL NULL. On error, an exception is raised and FALSE returned
 * (p is left empty). */
static int gp_pgsql_params_build(PlTerm params, gp_pgsql_params *p)
{
  int len = Pl_List_Length(params);
  PlTerm lst = params;
  PlTerm *cons;
  int i;

  p->values = NULL;
  p->n = 0;

  if (len < 0)
  {
    Pl_Err_Type(Pl_Create_Atom("list"), params);
    return FALSE;
  }
  if (len == 0)
  {
    return TRUE;
  }
  if (len > GP_PGSQL_MAX_PARAMS)	/* limit of the PostgreSQL protocol */
  {
    Pl_Err_Domain(Pl_Create_Atom("pgsql_parameter_list"), params);
    return FALSE;
  }

  p->values = (char **)calloc((size_t)len, sizeof(char *));
  if (!p->values)
  {
    Pl_Err_Resource(Pl_Create_Atom("memory"));
    return FALSE;
  }
  p->n = len;

  for (i = 0; (cons = Pl_Rd_List_Check(lst)) != NULL; i++)
  {
    PlTerm head = cons[0];

    if (Pl_List_Length(head) == 0)	/* [] : SQL NULL */
    {
      p->values[i] = NULL;
    } else {
      p->values[i] = gp_pgsql_text_owned(head);
      if (!p->values[i])
      {
        Pl_Err_Type(Pl_Create_Atom("pgsql_parameter"), head);
        gp_pgsql_params_free(p);
        return FALSE;
      }
    }
    lst = cons[1];
  }
  return TRUE;
}


/* Results */

/* the value of field fnum of row idx of result, as a Prolog term: an
 * integer/float for a numeric column, [] for SQL NULL, otherwise a code
 * list (not an atom: see the comment at the top of this file) */
static PlTerm gp_pgsql_cell_term(PGresult *result, int row, int fnum)
{
  char *txt;

  if (PQgetisnull(result, row, fnum))
  {
    return Pl_Mk_Atom(Pl_Atom_Nil());
  }
  txt = PQgetvalue(result, row, fnum);
  switch (pgsql_core_cell_kind_of(result, fnum))
  {
    case PL_PGSQL_CELL_INT:
      return Pl_Mk_Integer(strtol(txt, NULL, 10));
    case PL_PGSQL_CELL_FLOAT:
      return Pl_Mk_Float(strtod(txt, NULL));
    case PL_PGSQL_CELL_TEXT:
    default:
      return Pl_Mk_Codes(txt);
  }
}

static PlTerm gp_pgsql_row_term(PGresult *result, int row, int nfields)
{
  PlTerm vals[nfields ? nfields : 1];
  int f;

  for (f = 0; f < nfields; f++)
  {
    vals[f] = gp_pgsql_cell_term(result, row, f);
  }
  return Pl_Mk_Proper_List(nfields, vals);
}


/* Predicates */

/* pl_pgsql_connect(-Connection): connects using PGHOST, PGPORT, PGDATABASE */
PlBool pl_pgsql_connect1(PlTerm p_dbx)
{
  char errbuf[PL_PGSQL_ERRBUF_SIZE];
  PGconn *conn;
  long handle;

  if (!Pl_Builtin_Var(p_dbx))
  {
    return PL_FALSE;
  }

  conn = pgsql_core_connect_env(errbuf);
  if (!conn)
  {
    return gp_pgsql_error(errbuf, "pl_pgsql_connect", 1);
  }
  handle = gp_pgsql_table_alloc(conn);
  if (!handle)
  {
    PQfinish(conn);
    Pl_Err_Resource(Pl_Create_Atom("memory"));
    return PL_FALSE;
  }
  return Pl_Un_Integer_Check(handle, p_dbx);
}

/* pl_pgsql_connect(+Host, +Port, +User, +Password, +Dbname, -Connection) */
PlBool pl_pgsql_connect6(PlTerm p_host, PlTerm p_port, PlTerm p_user,
                         PlTerm p_passwd, PlTerm p_dbname, PlTerm p_dbx)
{
  char errbuf[PL_PGSQL_ERRBUF_SIZE];
  char *host, *port, *user = NULL, *passwd = NULL, *dbname;
  PGconn *conn;
  long handle;

  if (!Pl_Builtin_Var(p_dbx))
  {
    return PL_FALSE;
  }

  host = gp_pgsql_text_owned(p_host);
  port = gp_pgsql_text_owned(p_port);
  dbname = gp_pgsql_text_owned(p_dbname);
  if (!Pl_Builtin_Var(p_user))
  {
    user = gp_pgsql_text_owned(p_user);
  }
  if (!Pl_Builtin_Var(p_passwd))
  {
    passwd = gp_pgsql_text_owned(p_passwd);
  }

  if (!host || !port || !dbname)
  {
    free(host); free(port); free(user); free(passwd); free(dbname);
    return PL_FALSE;
  }

  conn = pgsql_core_connect(host, port, user, passwd, dbname, errbuf);
  free(host); free(port); free(user); free(passwd); free(dbname);

  if (!conn)
  {
    return gp_pgsql_error(errbuf, "pl_pgsql_connect", 6);
  }
  handle = gp_pgsql_table_alloc(conn);
  if (!handle)
  {
    PQfinish(conn);
    Pl_Err_Resource(Pl_Create_Atom("memory"));
    return PL_FALSE;
  }
  return Pl_Un_Integer_Check(handle, p_dbx);
}

/* pl_pgsql_disconnect(+Connection) */
PlBool pl_pgsql_disconnect1(PlTerm p_dbx)
{
  char errbuf[PL_PGSQL_ERRBUF_SIZE];
  PGconn *conn;
  PlLong idx;

  if (!gp_pgsql_get_conn(p_dbx, &conn))
  {
    return PL_FALSE;
  }
  if (!conn)
  {
    return PL_FALSE;	/* already disconnected */
  }

  idx = Pl_Rd_Integer_Check(p_dbx);
  if (!pgsql_core_disconnect(conn, errbuf))
  {
    gp_pgsql_table[idx - 1] = NULL;
    return gp_pgsql_error(errbuf, "pl_pgsql_disconnect", 1);
  }
  gp_pgsql_table[idx - 1] = NULL;
  return PL_TRUE;
}

/* pl_pgsql_query(+Connection, +Query): runs Query, no result rows */
PlBool pl_pgsql_query2(PlTerm p_dbx, PlTerm p_query)
{
  char errbuf[PL_PGSQL_ERRBUF_SIZE];
  PGconn *conn;
  PGresult *result;
  char *query;

  if (!gp_pgsql_get_open_conn(p_dbx, &conn))
  {
    return PL_FALSE;
  }
  query = gp_pgsql_text_owned(p_query);
  if (!query)
  {
    Pl_Err_Type(Pl_Create_Atom("text"), p_query);
    return PL_FALSE;
  }

  result = pgsql_core_exec(conn, query, 0, NULL, errbuf);
  free(query);
  if (!result)
  {
    return gp_pgsql_error(errbuf, "pl_pgsql_query", 2);
  }
  PQclear(result);
  return PL_TRUE;
}

/* pl_pgsql_exec(+Connection, +Query, +Params): like pl_pgsql_query/2, but
 * Query may contain $1, $2, ... placeholders bound to Params */
PlBool pl_pgsql_exec3(PlTerm p_dbx, PlTerm p_query, PlTerm p_params)
{
  char errbuf[PL_PGSQL_ERRBUF_SIZE];
  PGconn *conn;
  PGresult *result;
  char *query;
  gp_pgsql_params params;

  if (!gp_pgsql_get_open_conn(p_dbx, &conn))
  {
    return PL_FALSE;
  }
  if (!gp_pgsql_params_build(p_params, &params))
  {
    return PL_FALSE;
  }
  query = gp_pgsql_text_owned(p_query);
  if (!query)
  {
    gp_pgsql_params_free(&params);
    Pl_Err_Type(Pl_Create_Atom("text"), p_query);
    return PL_FALSE;
  }

  result = pgsql_core_exec(conn, query, params.n, (const char *const *)params.values, errbuf);
  free(query);
  gp_pgsql_params_free(&params);

  if (!result)
  {
    return gp_pgsql_error(errbuf, "pl_pgsql_exec", 3);
  }
  PQclear(result);
  return PL_TRUE;
}

/* shared by pl_pgsql_query_all/3 and pl_pgsql_query_all/4; has_params == 0
 * ignores p_params (and runs a plain, unparameterised query) */
static PlBool gp_pgsql_query_all_impl(PlTerm p_dbx, PlTerm p_query, PlTerm p_params,
                                      int has_params, PlTerm p_out,
                                      const char *who, int arity)
{
  char errbuf[PL_PGSQL_ERRBUF_SIZE];
  PGconn *conn;
  PGresult *result;
  char *query;
  gp_pgsql_params params;
  int nrows, nfields, r;
  PlBool ok;

  params.values = NULL;
  params.n = 0;

  if (!Pl_Builtin_Var(p_out))
  {
    return gp_pgsql_uninstantiation_error(p_out);
  }
  if (!gp_pgsql_get_open_conn(p_dbx, &conn))
  {
    return PL_FALSE;
  }
  if (has_params && !gp_pgsql_params_build(p_params, &params))
  {
    return PL_FALSE;
  }
  query = gp_pgsql_text_owned(p_query);
  if (!query)
  {
    gp_pgsql_params_free(&params);
    Pl_Err_Type(Pl_Create_Atom("text"), p_query);
    return PL_FALSE;
  }

  result = pgsql_core_exec(conn, query, params.n, (const char *const *)params.values, errbuf);
  free(query);
  gp_pgsql_params_free(&params);

  if (!result)
  {
    return gp_pgsql_error(errbuf, who, arity);
  }

  nrows = PQntuples(result);
  if (nrows <= 0)
  {
    PQclear(result);
    return PL_FALSE;
  }
  nfields = PQnfields(result);

  {
    PlTerm rows[nrows];
    for (r = 0; r < nrows; r++)
    {
      rows[r] = gp_pgsql_row_term(result, r, nfields);
    }
    ok = Pl_Un_Proper_List_Check(nrows, rows, p_out);
  }
  PQclear(result);
  return ok;
}

/* pl_pgsql_query_all(+Connection, +Query, -Rows): collects every row */
PlBool pl_pgsql_query_all3(PlTerm p_dbx, PlTerm p_query, PlTerm p_out)
{
  PlTerm unused = 0;
  return gp_pgsql_query_all_impl(p_dbx, p_query, unused, 0, p_out, "pl_pgsql_query_all", 3);
}

/* pl_pgsql_query_all(+Connection, +Query, +Params, -Rows) */
PlBool pl_pgsql_query_all4(PlTerm p_dbx, PlTerm p_query, PlTerm p_params, PlTerm p_out)
{
  return gp_pgsql_query_all_impl(p_dbx, p_query, p_params, 1, p_out, "pl_pgsql_query_all", 4);
}
