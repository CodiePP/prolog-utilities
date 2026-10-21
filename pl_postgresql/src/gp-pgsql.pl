/*-------------------------------------------------------------------------*/
/* Prolog Interface to PostgreSQL                                          */
/*                                                                         */
/* File  : gp-pgsql.pl                                                     */
/* Descr.:                                                                 */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2026 Alexander Diemand                               */
/*                                                                         */
/*   This program is free software: you can redistribute it and/or modify  */
/*   it under the terms of the GNU General Public License as published by  */
/*   the Free Software Foundation, either version 3 of the License, or     */
/*   (at your option) any later version.                                   */
/*                                                                         */
/*   This program is distributed in the hope that it will be useful,       */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*   GNU General Public License for more details.                          */
/*                                                                         */
/*   You should have received a copy of the GNU General Public License     */
/*   along with this program.  If not, see <http://www.gnu.org/licenses/>. */
/*-------------------------------------------------------------------------*/

% output args are plain "term" (checked manually in C), not "-term": this
% project's convention (matching gp-curl.pl/gp-regexp.pl) since GNU Prolog's
% compiler does something else with the term reference for a "-"-moded
% term argument, not pass the caller's own (possibly unbound) term.
:- foreign(pl_pgsql_connect(term), [fct_name(pl_pgsql_connect1)]).
:- foreign(pl_pgsql_connect(+term,+term,+term,+term,+term,term), [fct_name(pl_pgsql_connect6)]).
:- foreign(pl_pgsql_disconnect(+term), [fct_name(pl_pgsql_disconnect1)]).
:- foreign(pl_pgsql_query(+term,+term), [fct_name(pl_pgsql_query2)]).
:- foreign(pl_pgsql_exec(+term,+term,+term), [fct_name(pl_pgsql_exec3)]).
:- foreign(pl_pgsql_query_all(+term,+term,term), [fct_name(pl_pgsql_query_all3)]).
:- foreign(pl_pgsql_query_all(+term,+term,+term,term), [fct_name(pl_pgsql_query_all4)]).

% pl_pgsql_query(+Connection, +Query, -Row) backtracks over every row of
% Query's result set. It is implemented here, over pl_pgsql_query_all/3
% (deterministic at the C level), rather than with GNU Prolog's
% non-deterministic foreign call interface (choice_size/1, Pl_Err_*-style
% retry), which this bridge does not otherwise need. One consequence: a
% query error raised from here carries the context pl_pgsql_query_all/3,
% not pl_pgsql_query/3.
pl_pgsql_query(Connection, Query, Row) :-
    pl_pgsql_query_all(Connection, Query, Rows),
    member(Row, Rows).

info_pgsql :- write('Prolog Interface to PostgreSQL (GNU Prolog)'),nl,
              write('pl_pgsql_connect(Host,Port,User,Password,Dbname,Connection)'),nl,
              write('pl_pgsql_connect(Connection)  -- uses PGHOST, PGPORT, PGDATABASE'),nl,
              write('pl_pgsql_disconnect(Connection)'),nl,
              write('pl_pgsql_query(Connection, Query)'),nl,
              write('pl_pgsql_query(Connection, Query, Row)  -- backtracks over every row'),nl,
              write('pl_pgsql_exec(Connection, Query, Params)'),nl,
              write('pl_pgsql_query_all(Connection, Query, Rows)'),nl,
              write('pl_pgsql_query_all(Connection, Query, Params, Rows)'),nl,
              write('Params binds $1, $2, ... in Query; [] in Params is SQL NULL.'),nl,
              write('Text results are returned as code lists, not atoms.'),nl.
