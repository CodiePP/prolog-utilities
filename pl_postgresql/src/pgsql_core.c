/*   Prolog Interface to PostgreSQL
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

#include "pgsql_core.h"

/* copied from the python interface, should be defined in a pgsql header instead!! */
#define INT2OID         21
#define INT4OID         23
#define OIDOID          26
#define FLOAT4OID       700
#define FLOAT8OID       701
#define CASHOID         790

/* writes msg into errbuf, removing trailing whitespace (libpq error
 * messages end with a newline) */
static void set_errbuf(char errbuf[PL_PGSQL_ERRBUF_SIZE], const char *msg)
{
  size_t n;

  snprintf(errbuf, PL_PGSQL_ERRBUF_SIZE, "%s", msg);
  for (n = strlen(errbuf); n > 0 && (errbuf[n-1] == '\n' || errbuf[n-1] == '\r' || errbuf[n-1] == ' '); n--)
  {
    errbuf[n-1] = '\0';
  }
}

static const char *status_name(ConnStatusType status)
{
  switch (status)
  {
    case CONNECTION_SETENV:            return "CONNECTION_SETENV";
    case CONNECTION_AUTH_OK:           return "CONNECTION_AUTH_OK";
    case CONNECTION_AWAITING_RESPONSE: return "CONNECTION_AWAITING_RESPONSE";
    case CONNECTION_MADE:              return "CONNECTION_MADE";
    case CONNECTION_STARTED:           return "CONNECTION_STARTED";
    case CONNECTION_BAD:               return "CONNECTION_BAD";
    case CONNECTION_OK:                return "CONNECTION_OK";
    default:                           return "unknown connection status";
  }
}

PGconn *pgsql_core_connect(const char *host, const char *port, const char *user,
                           const char *passwd, const char *dbname,
                           char errbuf[PL_PGSQL_ERRBUF_SIZE])
{
  PGconn *conn = PQsetdbLogin(host, port, NULL, NULL, dbname, user, passwd);

  if (!conn)
  {
    set_errbuf(errbuf, "out of memory");
    return NULL;
  }
  if (PQstatus(conn) == CONNECTION_BAD)
  {
    char msg[PL_PGSQL_ERRBUF_SIZE];
    snprintf(msg, sizeof(msg), "connection to database %s failed: %s", dbname, PQerrorMessage(conn));
    set_errbuf(errbuf, msg);
    PQfinish(conn);
    return NULL;
  }
  return conn;
}

PGconn *pgsql_core_connect_env(char errbuf[PL_PGSQL_ERRBUF_SIZE])
{
  const char *host = getenv("PGHOST");
  const char *port = getenv("PGPORT");
  const char *dbname = getenv("PGDATABASE");

  if (!host)
  {
    set_errbuf(errbuf, "environment variable PGHOST is not set");
    return NULL;
  }
  if (!dbname)
  {
    set_errbuf(errbuf, "environment variable PGDATABASE is not set");
    return NULL;
  }
  return pgsql_core_connect(host, port ? port : "5432", NULL, NULL, dbname, errbuf);
}

int pgsql_core_is_connected(PGconn *conn)
{
  return PQstatus(conn) == CONNECTION_OK;
}

int pgsql_core_disconnect(PGconn *conn, char errbuf[PL_PGSQL_ERRBUF_SIZE])
{
  int ok = pgsql_core_is_connected(conn);

  if (!ok)
  {
    char msg[PL_PGSQL_ERRBUF_SIZE];
    snprintf(msg, sizeof(msg), "bad connection status: %s", status_name(PQstatus(conn)));
    set_errbuf(errbuf, msg);
  }
  PQfinish(conn);
  return ok;
}

PGresult *pgsql_core_exec(PGconn *conn, const char *query,
                          int nparams, const char *const *values,
                          char errbuf[PL_PGSQL_ERRBUF_SIZE])
{
  PGresult *result;
  ExecStatusType status;

  if (!pgsql_core_is_connected(conn))
  {
    char msg[PL_PGSQL_ERRBUF_SIZE];
    snprintf(msg, sizeof(msg), "bad connection status: %s", status_name(PQstatus(conn)));
    set_errbuf(errbuf, msg);
    return NULL;
  }

  if (nparams > 0)
  {
    result = PQexecParams(conn, query, nparams, NULL, values, NULL, NULL, 0);
  } else {
    result = PQexec(conn, query);
  }
  if (!result)
  {
    set_errbuf(errbuf, PQerrorMessage(conn));
    return NULL;
  }

  status = PQresultStatus(result);
  if (status != PGRES_COMMAND_OK && status != PGRES_TUPLES_OK)
  {
    char msg[PL_PGSQL_ERRBUF_SIZE];
    snprintf(msg, sizeof(msg), "%s: %s", PQresStatus(status), PQresultErrorMessage(result));
    set_errbuf(errbuf, msg);
    PQclear(result);
    return NULL;
  }
  return result;
}

pl_pgsql_cell_kind pgsql_core_cell_kind_of(PGresult *result, int fnum)
{
  switch (PQftype(result, fnum))
  {
    case INT2OID:
    case INT4OID:
    case OIDOID:
      return PL_PGSQL_CELL_INT;
    case FLOAT4OID:
    case FLOAT8OID:
    case CASHOID:
      return PL_PGSQL_CELL_FLOAT;
    default:
      return PL_PGSQL_CELL_TEXT;
  }
}
