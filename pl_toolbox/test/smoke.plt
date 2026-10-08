% Placeholder unit tests: they prove that the toolbox builds and loads in CI.
% Replace/extend with real tests (JSON parser, string, vector, ...).

:- use_module(library(plunit)).
:- use_module(sbcl(toolbox)).

:- begin_tests(toolbox_smoke).

test(vector_add) :-
    toolbox:vadd([1,2,3], [4,5,6], V),
    V == [5,7,9].

test(json_roundtrip) :-
    toolbox:from_json('{"a": [1, 2.5, "x"], "b": {}}', J),
    toolbox:to_json(J, A),
    toolbox:from_json(A, J2),
    J2 == J.

:- end_tests(toolbox_smoke).

:- begin_tests(toolbox_temporary_file).

tmp_dir(Dir) :-
    current_prolog_flag(tmp_dir, Dir).

test(creates_empty_private_file) :-
    tmp_dir(Dir),
    toolbox:pl_temporary_file(Dir, plutest, F),
    call_cleanup(( exists_file(F),
                   size_file(F, 0),
                   file_base_name(F, B),
                   sub_atom(B, 0, _, _, plute),
                   file_directory_name(F, D),
                   same_file(D, Dir) ),
                 delete_file(F)).

test(unique_names) :-
    tmp_dir(Dir),
    toolbox:pl_temporary_file(Dir, plu, F1),
    toolbox:pl_temporary_file(Dir, plu, F2),
    call_cleanup(F1 \== F2, ( delete_file(F1), delete_file(F2) )).

test(missing_directory_fails, [fail]) :-
    toolbox:pl_temporary_file('/no/such/directory', plu, _).

test(prefix_with_slash_fails, [fail]) :-
    tmp_dir(Dir),
    toolbox:pl_temporary_file(Dir, 'a/b', _).

:- end_tests(toolbox_temporary_file).
