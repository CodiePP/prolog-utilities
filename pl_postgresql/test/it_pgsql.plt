% Integration tests for the PostgreSQL bridge. They need a running server and
% the usual libpq environment: PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE.
% Run with ci/it-pgsql.sh (which waits for the server first).
%
% Tests marked fixme document known defects (see the repo review); a fixme
% test that starts to pass is reported as fixed, a failing one does not fail
% the run. Drop the fixme option once the defect is resolved.
% Not covered on purpose, because they crash the whole process (a crash
% cannot be reported as a single failing test):
%  - SQL errors in pl_pgsql_query_all/3: errmsg[256] is filled with
%    snprintf(errmsg, 1023, ...) in swi-pg-c.c; aborts under _FORTIFY_SOURCE
%    (Ubuntu's default), overflows the stack buffer otherwise;
%  - an over-long database name in pl_pgsql_connect/6 (sprintf into a 1024
%    byte buffer);
%  - using a connection handle after pl_pgsql_disconnect/1 (use after free).

:- use_module(library(plunit)).
:- use_module(sbcl(pgsql)).

env(Name, Default, Value) :-
    ( getenv(Name, Value) -> true ; Value = Default ).

connect(Conn) :-
    env('PGHOST', localhost, Host),
    env('PGPORT', '5432', PortAtom), atom_number(PortAtom, Port),
    env('PGUSER', postgres, User),
    env('PGPASSWORD', '', Password),
    env('PGDATABASE', postgres, Db),
    pl_pgsql_connect(Host, Port, User, Password, Db, Conn).

% with_conn/1 gives each test its own connection (temporary tables are per
% connection, so nothing is left behind).
with_conn(Goal) :-
    setup_call_cleanup(connect(C), call(Goal, C), pl_pgsql_disconnect(C)).

:- begin_tests(pgsql_integration).

test(select_int) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 3*7", R), R == [[21]] )).

test(select_float) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 1.5::float8", R), R == [[1.5]] )).

test(select_text) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 'abc'::text", R), R == [["abc"]] )).

test(table_roundtrip) :-
    with_conn([C]>>(
        pl_pgsql_query(C, "create temporary table t (id int, name text)"),
        pl_pgsql_query(C, "insert into t values (1, 'alice'), (2, 'bob')"),
        pl_pgsql_query_all(C, "select id, name from t order by id", R),
        R == [[1, "alice"], [2, "bob"]] )).

test(query_backtracks_over_rows) :-
    with_conn([C]>>(
        pl_pgsql_query(C, "create temporary table t (id int)"),
        pl_pgsql_query(C, "insert into t values (1), (2), (3)"),
        findall(Id, ( pl_pgsql_query(C, "select id from t order by id", Row), Row = [Id] ), Ids),
        Ids == [1, 2, 3] )).

test(empty_result_fails, [fail]) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 1 where false", _) )).

test(invalid_sql_raises_in_query3, [throws(error(_, 'pl_pgsql_query/3'))]) :-
    with_conn([C]>>( pl_pgsql_query(C, "select * from no_such_table", _) )).

test(connect_failure_raises, [throws(error(_, 'pl_pgsql_connect/6'))]) :-
    env('PGHOST', localhost, Host),
    env('PGPORT', '5432', PortAtom), atom_number(PortAtom, Port),
    pl_pgsql_connect(Host, Port, plu_no_such_user, wrong, no_such_db, _).

% --- known defects ----------------------------------------------------

test(invalid_sql_raises_in_query2, [fixme('SEC-2: pl_pgsql_query/2 reports success on SQL errors'),
                                    throws(error(_, 'pl_pgsql_query/2'))]) :-
    with_conn([C]>>( pl_pgsql_query(C, "select * from no_such_table") )).

test(text_starting_with_NULL_is_not_null,
     [fixme('text values starting with "NULL" are returned as []')]) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 'NULLABLE'::text", R), R == [["NULLABLE"]] )).

:- end_tests(pgsql_integration).
