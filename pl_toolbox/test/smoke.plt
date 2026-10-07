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
