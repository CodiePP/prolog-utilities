% Placeholder unit tests: they prove that the regexp library builds and loads in CI.

:- use_module(library(plunit)).
:- use_module(sbcl(regexp)).

:- begin_tests(regexp_smoke).

test(groups) :-
    regexp:pl_regexp("1999/12/11", "([0-9]+)/(.*)/(.*)", X),
    X == ['1999/12/11', '1999', '12', '11'].

test(no_match, [fail]) :-
    regexp:pl_regexp("abcdefg", "GNU", _).

:- end_tests(regexp_smoke).
