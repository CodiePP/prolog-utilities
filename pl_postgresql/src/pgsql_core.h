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

#ifndef PL_PGSQL_CORE_H
#define PL_PGSQL_CORE_H

/* the actual libpq work, shared between the GNU Prolog and SWI-Prolog
 * bridges. this file has no dependency on either Prolog C interface. */

#include <libpq-fe.h>

#define PL_PGSQL_ERRBUF_SIZE 1024

/* how a result column should be read; see pgsql_core_cell_kind_of() */
typedef enum {
  PL_PGSQL_CELL_INT,
  PL_PGSQL_CELL_FLOAT,
  PL_PGSQL_CELL_TEXT
} pl_pgsql_cell_kind;

/* connects with explicit login parameters. host, dbname and port must not
 * be NULL; user and passwd may be NULL to fall back to libpq defaults
 * (PGUSER/~/.pgpass/...). Returns NULL on failure with errbuf set to a
 * message describing it (no trailing newline); the caller owns no
 * resources to free in that case. */
PGconn *pgsql_core_connect(const char *host, const char *port, const char *user,
                            const char *passwd, const char *dbname,
                            char errbuf[PL_PGSQL_ERRBUF_SIZE]);

/* connects using PGHOST, PGPORT (default "5432") and PGDATABASE. Returns
 * NULL with errbuf set if PGHOST or PGDATABASE is not set, or the
 * connection fails. */
PGconn *pgsql_core_connect_env(char errbuf[PL_PGSQL_ERRBUF_SIZE]);

/* 1 if conn is still usable (PQstatus(conn) == CONNECTION_OK) */
int pgsql_core_is_connected(PGconn *conn);

/* finishes conn (always). Returns 1 if its status was CONNECTION_OK (a
 * clean, expected disconnect), 0 if it was already bad, with errbuf set to
 * a message describing the bad status; conn must not be used afterwards
 * either way. */
int pgsql_core_disconnect(PGconn *conn, char errbuf[PL_PGSQL_ERRBUF_SIZE]);

/* runs query on conn, optionally with nparams positional ($1, $2, ...)
 * parameters (values[i] == NULL sends SQL NULL); nparams == 0 runs a plain
 * PQexec, which (unlike PQexecParams) allows several ';'-separated
 * statements. Returns the result if its status is PGRES_COMMAND_OK or
 * PGRES_TUPLES_OK; otherwise NULL with errbuf set. The caller must PQclear()
 * a non-NULL result. */
PGresult *pgsql_core_exec(PGconn *conn, const char *query,
                           int nparams, const char *const *values,
                           char errbuf[PL_PGSQL_ERRBUF_SIZE]);

/* how field fnum of result should be converted to a Prolog term */
pl_pgsql_cell_kind pgsql_core_cell_kind_of(PGresult *result, int fnum);

#endif /* PL_PGSQL_CORE_H */
