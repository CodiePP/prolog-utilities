/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : JSON processing                                                 */
/* File  : json.pl                                                         */
/* Descr.: Decodes/encodes JSON text to/from Prolog terms.                 */
/*         Objects  <-> json([Name=Value, ...])                            */
/*         Arrays   <-> [Value, ...]                                       */
/*         Strings  <-> atom                                               */
/*         Numbers  <-> number                                             */
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
        encode_value(Json, Codes),
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

object(json([])) --> "{", ws, "}", !.
object(json(Pairs)) --> "{", ws, members(Pairs), ws, "}".

members([Pair]) --> pair(Pair).
members([Pair|Rest]) --> pair(Pair), ws, ",", ws, members(Rest).

pair(Name=Value) -->
        jstring(NameCodes), { atom_codes(Name, NameCodes) },
        ws, ":", ws, value(Value).

array([]) --> "[", ws, "]", !.
array(List) --> "[", ws, elements(List), ws, "]".

elements([V]) --> value(V).
elements([V|Rest]) --> value(V), ws, ",", ws, elements(Rest).

jstring(Codes) --> "\"", jchars(Codes), "\"".

jchars([C|Cs]) --> jchar(C), !, jchars(Cs).
jchars([]) --> [].

jchar(Code) --> [0'\\], [0'u], !, hex4(Code).
jchar(Code) --> [0'\\], [Esc], !, { unescape(Esc, Code) }.
jchar(Code) --> [Code], { Code \== 0'", Code \== 0'\\ }.

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
        { append(P1, P2, T), append(T, P3, Codes), number_codes(N, Codes) }.

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

encode_value(json(Pairs), Codes) :- !, encode_object(Pairs, Codes).
encode_value(List, Codes) :- is_list(List), !, encode_array(List, Codes).
encode_value(true, Codes) :- !, Codes = "true".
encode_value(false, Codes) :- !, Codes = "false".
encode_value(null, Codes) :- !, Codes = "null".
encode_value(N, Codes) :- number(N), !, number_codes(N, Codes).
encode_value(A, Codes) :- atom(A), !, encode_string(A, Codes).

encode_object([], Codes) :- !, Codes = "{}".
encode_object(Pairs, Codes) :-
        encode_members(Pairs, Inner),
        append([0'{], Inner, T), append(T, [0'}], Codes).

encode_members([Name=Value], Codes) :- !,
        encode_string(Name, NC),
        encode_value(Value, VC),
        append(NC, [0':], T), append(T, VC, Codes).
encode_members([Name=Value|Rest], Codes) :-
        encode_string(Name, NC),
        encode_value(Value, VC),
        encode_members(Rest, RC),
        append(NC, [0':], T1), append(T1, VC, T2), append(T2, [0',], T3), append(T3, RC, Codes).

encode_array([], Codes) :- !, Codes = "[]".
encode_array(List, Codes) :-
        encode_elements(List, Inner),
        append([0'[], Inner, T), append(T, [0']], Codes).

encode_elements([V], Codes) :- !, encode_value(V, Codes).
encode_elements([V|Vs], Codes) :-
        encode_value(V, VC),
        encode_elements(Vs, RC),
        append(VC, [0',], T), append(T, RC, Codes).

encode_string(Atom, Codes) :-
        atom_codes(Atom, Chars),
        escape_chars(Chars, Escaped),
        append([0'"], Escaped, T), append(T, [0'"], Codes).

escape_chars([], []).
escape_chars([C|Cs], Out) :-
        escape_char(C, EC),
        escape_chars(Cs, Rest),
        append(EC, Rest, Out).

escape_char(0'", [0'\\,0'"]) :- !.
escape_char(0'\\, [0'\\,0'\\]) :- !.
escape_char(10, [0'\\,0'n]) :- !.
escape_char(13, [0'\\,0'r]) :- !.
escape_char(9, [0'\\,0't]) :- !.
escape_char(C, [C]).

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
