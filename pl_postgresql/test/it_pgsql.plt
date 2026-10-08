% Integration tests for the PostgreSQL bridge. They need a running server and
% the usual libpq environment: PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE.
% Run with ci/it-pgsql.sh (which waits for the server first).

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

test(invalid_sql_raises_in_query3, [throws(error(pgsql_error(_), context(pl_pgsql_query/3, _)))]) :-
    with_conn([C]>>( pl_pgsql_query(C, "select * from no_such_table", _) )).

test(connect_failure_raises, [throws(error(pgsql_error(_), context(pl_pgsql_connect/6, _)))]) :-
    env('PGHOST', localhost, Host),
    env('PGPORT', '5432', PortAtom), atom_number(PortAtom, Port),
    pl_pgsql_connect(Host, Port, plu_no_such_user, wrong, no_such_db, _).

test(invalid_sql_raises_in_query2, [throws(error(pgsql_error(_), context(pl_pgsql_query/2, _)))]) :-
    with_conn([C]>>( pl_pgsql_query(C, "select * from no_such_table") )).

test(invalid_sql_raises_in_query_all, [throws(error(pgsql_error(_), context(pl_pgsql_query_all/3, _)))]) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select * from no_such_table", _) )).

test(text_starting_with_NULL_is_not_null) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 'NULLABLE'::text", R), R == [["NULLABLE"]] )).

test(sql_null_is_nil) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select null::text, null::int", R), R == [[[], []]] )).

test(long_dbname_raises, [throws(error(pgsql_error(_), context(pl_pgsql_connect/6, _)))]) :-
    env('PGHOST', localhost, Host),
    env('PGPORT', '5432', PortAtom), atom_number(PortAtom, Port),
    length(Cs, 5000), maplist(=(0'x), Cs), atom_codes(Db, Cs),
    pl_pgsql_connect(Host, Port, plu_no_such_user, wrong, Db, _).

% --- connection handles ------------------------------------------------

test(query_after_disconnect_raises, [throws(error(existence_error(pgsql_connection, _), _))]) :-
    connect(C),
    pl_pgsql_disconnect(C),
    pl_pgsql_query_all(C, "select 1", _).

test(disconnect_twice_fails, [fail]) :-
    connect(C),
    pl_pgsql_disconnect(C),
    pl_pgsql_disconnect(C).

test(integer_is_not_a_handle, [throws(error(type_error(pgsql_connection, 42), _))]) :-
    pl_pgsql_query_all(42, "select 1", _).

test(unclosed_connection_is_collected) :-
    connect(_),
    garbage_collect_atoms.

% --- parameterised queries ---------------------------------------------

test(query_all_params) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select $1::int + $2::int, $3::text",
                                        [20, '1', "x'; drop table t; --"], R),
                     R == [[21, "x'; drop table t; --"]] )).

test(query_all_params_null) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select $1::text is null", [[]], R),
                     R == [["t"]] )).

test(exec_params_roundtrip) :-
    with_conn([C]>>(
        pl_pgsql_query(C, "create temporary table t (id int, name text)"),
        pl_pgsql_exec(C, "insert into t values ($1, $2)", [1, "o'brien"]),
        pl_pgsql_exec(C, "insert into t values ($1, $2)", [2, []]),
        pl_pgsql_query_all(C, "select id, name from t order by id", R),
        R == [[1, "o'brien"], [2, []]] )).

test(exec_invalid_sql_raises, [throws(error(pgsql_error(_), context(pl_pgsql_exec/3, _)))]) :-
    with_conn([C]>>( pl_pgsql_exec(C, "select * from no_such_table where id = $1", [1]) )).

test(params_not_a_list, [throws(error(type_error(list, foo), _))]) :-
    with_conn([C]>>( pl_pgsql_exec(C, "select 1", foo) )).

test(param_wrong_type, [throws(error(type_error(pgsql_parameter, f(x)), _))]) :-
    with_conn([C]>>( pl_pgsql_exec(C, "select $1::text", [f(x)]) )).

test(output_must_be_unbound, [throws(error(uninstantiation_error(x), _))]) :-
    with_conn([C]>>( pl_pgsql_query_all(C, "select 1", x) )).

test(error_message_is_readable) :-
    catch(with_conn([C]>>( pl_pgsql_query(C, "select * from no_such_table") )), E, true),
    message_text(E, Msg),
    once(sub_string(Msg, _, _, _, "PostgreSQL: PGRES_FATAL_ERROR")).

message_text(E, Text) :-
    '$messages':translate_message(E, Lines, []),
    with_output_to(string(Text), print_message_lines(current_output, '', Lines)).

:- end_tests(pgsql_integration).
