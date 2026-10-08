% Timing tests for the JSON parser and encoder. The limits are generous
% (about 10x a laptop's time) so they only catch algorithmic regressions:
% quadratic string building, or reparsing on backtracking (which made the
% parser exponential in the nesting depth).

:- use_module(library(plunit)).
:- use_module(library(time)).
:- use_module(sbcl(toolbox)).

% about 1 MB of JSON: {"items": [{"id": 1, "name": "abc", ...}, ...]}
big_doc(json([items=Items])) :-
    numlist(1, 20000, Ns),
    findall(json([id=I, name=abc, tags=[x, 'y "z"'], v=1.5, ok=true]),
            member(I, Ns), Items).

% [[[...[1, 1]..., 1], 1], 1]: two elements on every level
nested(0, 1) :- !.
nested(N, [X, 1]) :- N1 is N - 1, nested(N1, X).

:- begin_tests(json_perf).

test(encode_decode_1mb) :-
    big_doc(J),
    call_with_time_limit(5, toolbox:to_json(J, A)),
    atom_length(A, Len),
    assertion(Len > 1000000),
    call_with_time_limit(10, toolbox:from_json(A, J2)),
    assertion(J2 == J).

test(deep_nesting_is_linear) :-
    nested(1000, J),
    toolbox:to_json(J, A),
    call_with_time_limit(2, toolbox:from_json(A, J2)),
    assertion(J2 == J).

:- end_tests(json_perf).
