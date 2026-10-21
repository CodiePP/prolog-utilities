/* gplc -o test-gp --new-top-level test-gp.pl libplpgsql-$(uname -s).a -L "$(pkg-config --libs libpq)" */

% needs PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE (see ci/it-pgsql.sh)

% environ/2 (not getenv/2 or atom_number/2: GNU Prolog built-ins differ
% from SWI-Prolog here)
env(Name, Default, Value) :-
  ( environ(Name, Value) -> true ; Value = Default ).

atom_to_number(Atom, Number) :-
  atom_codes(Atom, Codes),
  number_codes(Number, Codes).

testpgsql :-
  env('PGHOST', localhost, Host),
  env('PGPORT', '5432', PortAtom), atom_to_number(PortAtom, Port),
  env('PGUSER', postgres, User),
  env('PGPASSWORD', '', Password),
  env('PGDATABASE', postgres, Db),
  pl_pgsql_connect(Host, Port, User, Password, Db, Conn),
  format("connected: ~p~n", [Conn]),
  pl_pgsql_query_all(Conn, "select 3*7, 'hello'::text", Rows),
  format("rows: ~p~n", [Rows]),
  pl_pgsql_exec(Conn, "create temporary table t (id int, name text)", []),
  pl_pgsql_exec(Conn, "insert into t values ($1, $2)", [1, "o'brien"]),
  ( pl_pgsql_query(Conn, "select id, name from t order by id", Row),
    format("row: ~p~n", [Row]),
    fail
  ; true
  ),
  pl_pgsql_disconnect(Conn).
