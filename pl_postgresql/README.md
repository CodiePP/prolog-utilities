Interface to the PostgreSQL Database Server from [GNU|SWI] Prolog
=================================================================


PREDICATES
----------

`pl_pgsql_connect/6 (+host,+port,+user,+password,+dbname,-connection)`
    connect to the server on host as user with password, returns the 
    connection handle, which must be used in further request.

`pl_pgsql_connect/1 (-connection)`
    connect using the environment variables PGHOST, PGPORT and PGDATABASE.

`pl_pgsql_disconnect/1 (+connection)`
    close the connection. Fails if the connection is already closed.

`pl_pgsql_query/2 (+connection,+query)`
    sends the query to the server. There is no result.
    Used for insert/update/delete.

`pl_pgsql_query/3 (+connection,+query,-result)`
    sends the query to the server. This predicate is backtrackable and succeeds
    for every row in the result set of the query.

`pl_pgsql_query_all/3 (+connection,+query,-results)`
    sends the query to the server. This predicate is deterministic and collects
    all rows from the result set of the query.

`pl_pgsql_exec/3 (+connection,+query,+params)`
    like `pl_pgsql_query/2`, but the query may contain the placeholders
    `$1`, `$2`, ... which are bound to the values in the list params.

`pl_pgsql_query_all/4 (+connection,+query,+params,-results)`
    like `pl_pgsql_query_all/3`, with placeholders bound to params.

Errors are raised as `error(pgsql_error(Message), context(Predicate, _))`,
e.g. when the server rejects a query or a connection cannot be made. Using a
closed connection raises `existence_error(pgsql_connection, Handle)`, passing
something else as a handle a `type_error(pgsql_connection, Term)`.
SQL NULL values are returned as `[]`.


PARAMETERISED QUERIES
---------------------

Never build SQL by concatenating values that come from users: use
`pl_pgsql_exec/3` or `pl_pgsql_query_all/4` instead. The values are sent
separately from the query text (libpq `PQexecParams`), so they cannot change
the meaning of the statement.

A parameter is an atom, string, number or code list; `[]` is sent as SQL
NULL (so an empty string must be passed as `''` or `""`, not as an empty code
list). The server infers the parameter types from the query; add a cast
(`$1::int`) where it cannot.

```
| ?- pl_pgsql_exec(DBx, "insert into addresses (nr, name) values ($1, $2)", [42, "O'Brien"]),
     pl_pgsql_query_all(DBx, "select name from addresses where nr = $1", [42], Rows).
```


CONNECTION HANDLES
------------------

A connection handle is an opaque blob, printed as `<pgsql_connection>(...)`.
Using it after `pl_pgsql_disconnect/1` raises an existence error; anything
that is not a handle raises a type error. A connection that is never disconnected is closed
when its handle is garbage collected, but do not rely on that: always
disconnect (e.g. with `setup_call_cleanup/3`).


EXAMPLES
--------

load module:
```
use_module(sbcl(pgsql)).
```


1) something that works:

```
| ?- pl_pgsql_connect("localhost",5432,"testuser","my_password","postgres",DBx),
     pl_pgsql_query(DBx,"select 3*7",Result),
     format("result: ~d~n",Result),
     pl_pgsql_disconnect(DBx).
```

2) better: we should always succeed a query to disconnect from the db at the end

```
  run_query(DBx) :-
     pl_pgsql_query(DBx,"select nr,name,city from addresses",Result),
     format("~d: ~s lives in ~s~n",Result),
     fail,  % to backtrack over next row in Result

  run_query(_DBx).  % always succeed
```	

```
| ?- pl_pgsql_connect("localhost",5432,"test","my_password","the_db",DBx),
     run_query(DBx),
     pl_pgsql_disconnect(DBx).
```


HOW TO COMPILE
--------------

```sh
autoreconf -fi
```
(needs autoconf >= 2.70, which also installs the helper scripts in `config/`)
then run
```sh
./configure
```
then call `make`


INSTALLATION
------------

copy the plpgsql-<ARC> file to where your search path points to.
I have added the following in the file ~/.config/swi-prolog/init.pl:

> :- assertz(file_search_path(sbcl,'/home/<username>/lib/sbcl')). 

also copy the src/pgsql.qlf to this directory


COMMENTS
--------

Text arguments (queries, parameters, connection settings) may be atoms,
strings or code lists. In results, `int2`/`int4`/`oid` columns are returned
as integers, `float4`/`float8`/`money` as floats, SQL NULL as `[]` and
everything else as SWI-Prolog strings.

There is no GNU Prolog bridge for this module.


LICENSE
-------

Copyright (C) 1999-2026  Alexander Diemand

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
