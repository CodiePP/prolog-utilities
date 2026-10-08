% Unit tests for pl_regexp/3: Matches is [Whole, Group1, ..., GroupN].

:- use_module(library(plunit)).
:- use_module(sbcl(regexp)).

:- begin_tests(regexp_smoke).

test(groups) :-
    regexp:pl_regexp("1999/12/11", "([0-9]+)/(.*)/(.*)", X),
    X == ['1999/12/11', '1999', '12', '11'].

test(no_groups_gives_whole_match) :-
    regexp:pl_regexp("abcdefg", "c.e", X),
    X == [cde].

test(unmatched_group_is_empty) :-
    regexp:pl_regexp("ac", "a(b)?(c)", X),
    X == [ac, '', c].

test(no_match, [fail]) :-
    regexp:pl_regexp("abcdefg", "GNU", _).

test(invalid_pattern, [throws(error(syntax_error(_), context(pl_regexp/3, _)))]) :-
    regexp:pl_regexp("abc", "a(b", _).

test(unbound_input, [throws(error(instantiation_error, _))]) :-
    pl_regexp(_, "a", _).

test(exported) :-
    pl_regexp("abc", "b", [b]).

test(pattern_not_text, [throws(error(type_error(text, f(x)), _))]) :-
    regexp:pl_regexp("abc", f(x), _).

test(repeated_calls_do_not_leak) :-
    forall(between(1, 10000, _), regexp:pl_regexp("x=1", "(.)=(.)", _)).

:- end_tests(regexp_smoke).
