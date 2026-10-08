/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : JSON processing                                                 */
/* File  : json.pl                                                         */
/* Descr.: Decodes/encodes JSON text to/from Prolog terms.                 */
/*         Objects  <-> json([Name=Value, ...])                            */
/*         Arrays   <-> [Value, ...]                                       */
/*         Strings  <-> atom                                               */
/*         Numbers  <-> number (atom of its digits if out of range)        */
/*         true/false/null <-> the atoms true/false/null                   */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 2023-2026 Alexander Diemand                               */
/*                                                                         */
/*   This program is free software: you can redistribute it and/or modify  */
/*   it under the terms of the GNU General Public License as published by  */
/*   the Free Software Foundation, either version 3 of the License, or     */
/*   (at your option) any later version.                                   */
/*                                                                         */
/*   This program is distributed in the hope that it will be useful,       */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*   GNU General Public License for more details.                          */
/*                                                                         */
/*   You should have received a copy of the GNU General Public License     */
/*   along with this program.  If not, see <http://www.gnu.org/licenses/>. */
/*-------------------------------------------------------------------------*/

:- set_prolog_flag(double_quotes, codes).

info_json :-
        write('Prolog Toolbox, JSON processing'),nl,
        info_from_json.

info_from_json :-
        write('from_json(Input,Json)             decodes Input (atom/string/codes) into a Json term'),nl,
        write('to_json(Json,Atom)                encodes a Json term into an atom'),nl,
        write('json_print(Json)                  prints the Json term to the current stream'),nl.

/* -------------------------------------------------------------------- */
/* public                                                                */
/* -------------------------------------------------------------------- */

% from_json(+Input, -Json)
%   Input : atom, code list, or (SWI) string holding a JSON document.
%   Json  : json([Name=Value, ...])   for a JSON object
%           [Value, ...]              for a JSON array
%           Atom                      for a JSON string
%           Number                    for a JSON number
%           true / false / null       for JSON literals

from_json(Input, Json) :-
        json_to_codes(Input, Codes),
        phrase(json_top(Json), Codes).

% to_json(+Json, -Atom)
%   inverse of from_json/2; Atom holds the compact JSON text.

to_json(Json, Atom) :-
        phrase(encode_value(Json), Codes),
        atom_codes(Atom, Codes).

json_from_file(Filename, Json) :-
        open(Filename, read, Stream),
        read_stream_to_codes(Stream, Codes),
        close(Stream),
        phrase(json_top(Json), Codes).

read_stream_to_codes(Stream, Codes) :-
        get_code(Stream, C),
        read_stream_to_codes(Stream, C, Codes).

read_stream_to_codes(_Stream, -1, []) :- !.
read_stream_to_codes(Stream, C, [C|Cs]) :-
        get_code(Stream, C2),
        read_stream_to_codes(Stream, C2, Cs).

/* -------------------------------------------------------------------- */
/* input coercion                                                       */
/* -------------------------------------------------------------------- */

json_to_codes(Codes, Codes) :- is_list(Codes), !.
json_to_codes(Atom, Codes) :- atom(Atom), !, atom_codes(Atom, Codes).
json_to_codes(Str, Codes) :-
        % SWI-Prolog string object; string/1 and string_codes/2 do not
        % exist in GNU Prolog, but this clause is only reached for a
        % term that is neither a list nor an atom, so it is never
        % called there.
        catch(( string(Str), string_codes(Str, Codes) ), _, fail).

/* -------------------------------------------------------------------- */
/* decode : grammar                                                     */
/* -------------------------------------------------------------------- */

json_top(V) --> ws, value(V), ws.

value(V) --> jstring(Codes), !, { atom_codes(V, Codes) }.
value(V) --> object(V), !.
value(V) --> array(V), !.
value(true) --> "true", !.
value(false) --> "false", !.
value(null) --> "null", !.
value(N) --> number_val(N).

% members and elements are parsed deterministically: each value is parsed
% once and the next character decides between "," and the closing bracket.
% (Alternative clauses for one and for several values parsed the value
% again on backtracking, which doubled the work per nesting level.)
object(json([])) --> "{", ws, "}", !.
object(json([Pair|Rest])) --> "{", ws, pair(Pair), ws, members(Rest), "}".

members([Pair|Rest]) --> ",", !, ws, pair(Pair), ws, members(Rest).
members([]) --> [].

pair(Name=Value) -->
        jstring(NameCodes), { atom_codes(Name, NameCodes) },
        ws, ":", ws, value(Value).

array([]) --> "[", ws, "]", !.
array([V|Rest]) --> "[", ws, value(V), ws, elements(Rest), "]".

elements([V|Rest]) --> ",", !, ws, value(V), ws, elements(Rest).
elements([]) --> [].

jstring(Codes) --> "\"", jchars(Codes), "\"".

% jchar(-Codes, ?Tail): one character of a string, as a difference list
% (a \u escape may expand to several bytes, see code_point/3)
jchars(Codes) --> jchar(Codes, Tail), !, jchars(Tail).
jchars([]) --> [].

jchar(Codes, Tail) -->
        [0'\\], [0'u], hex4(Hi), { Hi >= 0xD800, Hi =< 0xDBFF },
        [0'\\], [0'u], hex4(Lo), { Lo >= 0xDC00, Lo =< 0xDFFF }, !,
        { CP is 0x10000 + (Hi - 0xD800) * 1024 + (Lo - 0xDC00),
          code_point(CP, Codes, Tail) }.
jchar(Codes, Tail) --> [0'\\], [0'u], !, hex4(CP), { code_point(CP, Codes, Tail) }.
jchar([Code|Tail], Tail) --> [0'\\], [Esc], !, { unescape(Esc, Code) }.
jchar([Code|Tail], Tail) --> [Code], { Code \== 0'", Code \== 0'\\ }.

% code_point(+CP, -Codes, ?Tail)
%   where atoms hold Unicode characters (SWI-Prolog) the code point is
%   kept as is; where atoms are byte strings (GNU Prolog) it is encoded
%   as UTF-8, matching how unescaped non-ASCII text arrives there.
code_point(CP, [CP|Tail], Tail) :- CP < 0x80, !.
code_point(CP, [CP|Tail], Tail) :- wide_atoms, !.
code_point(CP, [B1,B2|Tail], Tail) :- CP < 0x800, !,
        B1 is 0xC0 \/ (CP >> 6),
        B2 is 0x80 \/ (CP /\ 0x3F).
code_point(CP, [B1,B2,B3|Tail], Tail) :- CP < 0x10000, !,
        B1 is 0xE0 \/ (CP >> 12),
        B2 is 0x80 \/ ((CP >> 6) /\ 0x3F),
        B3 is 0x80 \/ (CP /\ 0x3F).
code_point(CP, [B1,B2,B3,B4|Tail], Tail) :-
        B1 is 0xF0 \/ (CP >> 18),
        B2 is 0x80 \/ ((CP >> 12) /\ 0x3F),
        B3 is 0x80 \/ ((CP >> 6) /\ 0x3F),
        B4 is 0x80 \/ (CP /\ 0x3F).

wide_atoms :- catch(atom_codes(_, [0x100]), _, fail).

unescape(0'", 0'") :- !.
unescape(0'\\, 0'\\) :- !.
unescape(0'/, 0'/) :- !.
unescape(0'b, 8) :- !.
unescape(0'f, 12) :- !.
unescape(0'n, 10) :- !.
unescape(0'r, 13) :- !.
unescape(0't, 9) :- !.

hex4(Code) -->
        [H1,H2,H3,H4],
        { hexval(H1,V1), hexval(H2,V2), hexval(H3,V3), hexval(H4,V4),
          Code is ((V1*16+V2)*16+V3)*16+V4 }.

hexval(C,V) :- C >= 0'0, C =< 0'9, !, V is C - 0'0.
hexval(C,V) :- C >= 0'a, C =< 0'f, !, V is C - 0'a + 10.
hexval(C,V) :- C >= 0'A, C =< 0'F, !, V is C - 0'A + 10.

number_val(N) -->
        int_part(P1), frac_part(P2), exp_part(P3),
        { iso_frac(P2, P3, F),
          append(P1, F, T), append(T, P3, Codes), number_from_codes(Codes, N) }.

% ISO Prolog (GNU) needs a fraction before the exponent: 1e2 -> 1.0e2
iso_frac([], [_|_], ".0") :- !.
iso_frac(F, _, F).

% a number out of range for this Prolog (e.g. integers beyond
% max_integer in GNU Prolog) is returned as an atom of its digits
number_from_codes(Codes, N) :-
        catch(number_codes(N, Codes), error(_, _), fail), !.
number_from_codes(Codes, A) :-
        atom_codes(A, Codes).

int_part(Codes) --> minus(M), digits1(D), { append(M, D, Codes) }.

minus([0'-]) --> "-", !.
minus([]) --> [].

digits1([D|Ds]) --> digit(D), digits0(Ds).
digits0([D|Ds]) --> digit(D), !, digits0(Ds).
digits0([]) --> [].
digit(D) --> [D], { D >= 0'0, D =< 0'9 }.

frac_part(Codes) --> ".", !, digits1(D), { Codes = [0'.|D] }.
frac_part([]) --> [].

exp_part(Codes) -->
        [E], { E =:= 0'e ; E =:= 0'E }, !,
        sign(Sg), digits1(D), { append([E|Sg], D, Codes) }.
exp_part([]) --> [].

sign([0'+]) --> "+", !.
sign([0'-]) --> "-", !.
sign([]) --> [].

ws --> [C], { ws_char(C) }, !, ws.
ws --> [].
ws_char(0' ). ws_char(9). ws_char(10). ws_char(13).

/* -------------------------------------------------------------------- */
/* encode                                                                */
/* -------------------------------------------------------------------- */

% a grammar producing the codes: every part is written once into the
% output list (no append/3 of intermediate lists)

encode_value(json(Pairs)) --> !, "{", encode_members(Pairs), "}".
encode_value(List) --> { is_list(List) }, !, "[", encode_elements(List), "]".
encode_value(true) --> !, "true".
encode_value(false) --> !, "false".
encode_value(null) --> !, "null".
encode_value(N) --> { number(N) }, !, { number_codes(N, Codes) }, json_codes(Codes).
encode_value(A) --> { atom(A) }, !, encode_string(A).

encode_members([]) --> [].
encode_members([Pair|Rest]) --> encode_member(Pair), encode_members_rest(Rest).

encode_members_rest([]) --> [].
encode_members_rest([Pair|Rest]) --> ",", encode_member(Pair), encode_members_rest(Rest).

encode_member(Name=Value) --> encode_string(Name), ":", encode_value(Value).

encode_elements([]) --> [].
encode_elements([V|Vs]) --> encode_value(V), encode_elements_rest(Vs).

encode_elements_rest([]) --> [].
encode_elements_rest([V|Vs]) --> ",", encode_value(V), encode_elements_rest(Vs).

encode_string(Atom) -->
        { atom_codes(Atom, Chars) },
        "\"", escape_chars(Chars), "\"".

escape_chars([]) --> [].
escape_chars([C|Cs]) --> { escape_char(C, EC) }, json_codes(EC), escape_chars(Cs).

json_codes([]) --> [].
json_codes([C|Cs]) --> [C], json_codes(Cs).

escape_char(0'", [0'\\,0'"]) :- !.
escape_char(0'\\, [0'\\,0'\\]) :- !.
escape_char(10, [0'\\,0'n]) :- !.
escape_char(13, [0'\\,0'r]) :- !.
escape_char(9, [0'\\,0't]) :- !.
escape_char(8, [0'\\,0'b]) :- !.
escape_char(12, [0'\\,0'f]) :- !.
escape_char(C, [0'\\,0'u,0'0,0'0,H1,H2]) :- C < 32, !,
        hexdigit(C >> 4, H1),
        hexdigit(C /\ 15, H2).
escape_char(C, [C]).

hexdigit(Expr, D) :- V is Expr, ( V < 10 -> D is 0'0 + V ; D is 0'a + V - 10 ).

/* -------------------------------------------------------------------- */
/* pretty print                                                          */
/* -------------------------------------------------------------------- */

json_print(Json) :-
        json_print2(Json, 0).

json_print2(json(Pairs), Indent) :- !,
        format("{~n",[]),
        NewIndent is Indent + 2,
        json_print_members(Pairs, NewIndent),
        indent(Indent),
        format("}",[]).
json_print2(List, Indent) :-
        is_list(List), !,
        format("[~n",[]),
        NewIndent is Indent + 2,
        json_print_elements(List, NewIndent),
        indent(Indent),
        format("]",[]).
json_print2(true, _Indent) :- !, format("true",[]).
json_print2(false, _Indent) :- !, format("false",[]).
json_print2(null, _Indent) :- !, format("null",[]).
json_print2(N, _Indent) :- number(N), !, format("~q",[N]).
json_print2(A, _Indent) :- atom(A), !, format("~q",[A]).

json_print_members([], _Indent) :- !.
json_print_members([Name=Value], Indent) :- !,
        indent(Indent),
        format("~q: ", [Name]),
        json_print2(Value, Indent), nl.
json_print_members([Name=Value|Rest], Indent) :-
        indent(Indent),
        format("~q: ", [Name]),
        json_print2(Value, Indent), format(",~n",[]),
        json_print_members(Rest, Indent).

json_print_elements([], _Indent) :- !.
json_print_elements([V], Indent) :- !,
        indent(Indent), json_print2(V, Indent), nl.
json_print_elements([V|Rest], Indent) :-
        indent(Indent), json_print2(V, Indent), format(",~n",[]),
        json_print_elements(Rest, Indent).

indent(0) :- !.
indent(Indent) :-
        put_char(' '),
        NewIndent is Indent - 1,
        indent(NewIndent).
