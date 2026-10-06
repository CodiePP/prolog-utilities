/*-------------------------------------------------------------------------*/
/* Prolog Toolbox -- tests for src/json.pl, GNU Prolog and SWI-Prolog      */
/*                                                                         */
/*   $ make check                                                          */
/*                                                                         */
/*   GNU: gplc --no-top-level -o test_json test/test_json.pl src/json.pl   */
/*        ./test_json                                                      */
/*   SWI: swipl -q src/json.pl test/test_json.pl                           */
/*                                                                         */
/* exits with status 0 on success, 1 on failure.                          */
/*-------------------------------------------------------------------------*/

:- initialization(main).

main :-
        findall(Name, ( test(Name, Goal), \+ run(Goal) ), Failed),
        findall(Name, test(Name, _), All),
        length(All, N), length(Failed, F),
        format("json: ~w tests, ~w failed ~w~n", [N, F, Failed]),
        ( Failed == [] -> halt(0) ; halt(1) ).

run(Goal) :- catch(Goal, E, (format("  exception: ~q~n", [E]), fail)), !.

% expected codes of a decoded \u escape: the code point where atoms are
% Unicode (SWI-Prolog), its UTF-8 bytes where they are bytes (GNU Prolog)
uchar(CP, _, [CP]) :- wide_atoms, !.
uchar(_, Utf8, Utf8).

decoded_codes(Text, Codes) :- from_json(Text, A), atom_codes(A, Codes).

test(empty_object, from_json('{}', json([]))).
test(empty_array, from_json(' [ ] ', [])).
test(nested, (
        from_json('{"a": {"b": [1, {"c": []}]}, "d": {}}', J),
        J == json([a=json([b=[1, json([c=[]])]]), d=json([])]) )).
test(literals, from_json('[true, false, null]', [true, false, null])).
test(numbers, (
        from_json('[0, -12, 3.5, -2.5e1, 1E2]', [A, B, C, D, E]),
        A == 0, B == -12, C =:= 3.5, D =:= -25.0, E =:= 100.0 )).
test(escapes, (
        decoded_codes('"q\\"b\\\\s\\/n\\n\\t\\r\\b\\f"', Cs),
        Cs == [0'q, 0'", 0'b, 0'\\, 0's, 0'/, 0'n, 10, 9, 13, 8, 12] )).
test(unicode_ascii, decoded_codes('"\\u0041"', [0'A])).
test(unicode_latin1, (
        uchar(0xE9, [0xC3, 0xA9], X),
        decoded_codes('"caf\\u00e9"', Cs), Cs == [0'c, 0'a, 0'f | X] )).
test(unicode_bmp, (
        uchar(0x20AC, [0xE2, 0x82, 0xAC], X),
        decoded_codes('"\\u20ac"', Cs), Cs == X )).
test(unicode_surrogate_pair, (
        uchar(0x1F600, [0xF0, 0x9F, 0x98, 0x80], X),
        decoded_codes('"\\ud83d\\ude00!"', Cs), append(X, [0'!], Cs) )).
test(raw_utf8_passthrough, (
        from_json([0'", 0xC3, 0xA9, 0'"], A), atom_codes(A, [0xC3, 0xA9]) )).
test(big_integer, (
        from_json('{"n": 123456789012345678901234567890}', json([n=N])),
        ( integer(N) -> number_codes(N, Cs), atom_codes(A, Cs) ; A = N ),
        A == '123456789012345678901234567890' )).
test(invalid_value, \+ from_json('{"a":}', _)).
test(trailing_garbage, \+ from_json('{} x', _)).
test(unterminated_string, \+ from_json('"abc', _)).
test(unknown_escape, \+ from_json('"\\x"', _)).
test(encode, (
        to_json(json([k='a"b\\c', l=[1, -2.5, true, null], m=json([]), n=[]]), T),
        T == '{"k":"a\\"b\\\\c","l":[1,-2.5,true,null],"m":{},"n":[]}' )).
test(encode_control_chars, (
        atom_codes(A, [0'a, 10, 9, 8, 12, 1, 31]),
        to_json(json([k=A]), T),
        T == '{"k":"a\\n\\t\\b\\f\\u0001\\u001f"}' )).
test(round_trip, (
        atom_codes(S, [0'x, 0'", 10, 1, 0'y]),
        J = json([s=S, l=[json([]), [], 0, true], o=json([k=v])]),
        to_json(J, T), from_json(T, J2), J2 == J )).
