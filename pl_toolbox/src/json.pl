/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : JSON processing                                                 */
/* File  : json.pl                                                         */
/* Descr.: Parses JSON structures and represents them as lists of pairs    */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 2023 Alexander Diemand                                    */
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

info_json :-
        write('Prolog Toolbox, JSON processing'),nl,
        info_from_json.


% Reads in a JSON structure

info_from_json :-
        %      ^                                ^
        write('from_json(Stream,Json)           reads from Stream and returns the structure'),nl,
        write('json_print(Json)                 prints the Json structure to the current stream'),nl.

from_json(Stream, Json) :-
        rec_from_json(Stream, has_value(structure,[]), Json).

rec_from_json(Stream, has_value(structure,Acc), JsonOut) :-
        read_json_value(Stream, Value),
        ( Value = [] -> [JsonOut] = Acc
        ; append(Value, Acc, NewAcc), rec_from_json(Stream, has_value(structure, NewAcc), JsonOut)).

read_json_value(Stream, ValueOut) :-
        get_code(Stream, Char),
        read_json_value4(Stream, Char, [], ValueOut).

read_json_value4(Stream, Ws, Acc, ValueOut) :-
        member(Ws, [32, 9, 10, 13]), !,  % whitespace
        get_code(Stream, Char),
        read_json_value4(Stream, Char, Acc, ValueOut).

% end of stream
read_json_value4(_Stream, -1, ValueOut, ValueOut) :- !.

% "\""
read_json_value4(Stream, 34, Acc, ValueOut) :-
        read_txtuntil(Stream, 34, String),
        get_code(Stream, NextChar),
        !, read_json_value4(Stream, NextChar, [has_value(string,String) | Acc], ValueOut).

% [+-0123456789.]
read_json_value4(Stream, Char, Acc, ValueOut) :-
        member(Char, [43,45,48,49,50,51,52,53,54,55,56,57,46]), !, % [+-0123456789.]
        read_txtwhile(Stream, [43,45,48,49,50,51,52,53,54,55,56,57,46], [Char], NumCodes, NextChar),
        number_codes(Number, NumCodes),
        read_json_value4(Stream, NextChar, [has_value(number,Number) | Acc], ValueOut), !.

% false = [102, 97, 108, 115, 101]
read_json_value4(Stream, 102, Acc, ValueOut) :-
        get_code(Stream, 97), get_code(Stream, 108), get_code(Stream, 115),
        get_code(Stream, 101), get_code(Stream, NextChar), !,
        read_json_value4(Stream, NextChar, [has_value(boolean,false) | Acc], ValueOut).

% true = [116, 114, 117, 101]
read_json_value4(Stream, 116, Acc, ValueOut) :-
        get_code(Stream, 114), get_code(Stream, 117), get_code(Stream, 101),
        get_code(Stream, NextChar), !,
        read_json_value4(Stream, NextChar, [has_value(boolean,true) | Acc], ValueOut).

% null = [110,117,108,108]
read_json_value4(Stream, 110, Acc, ValueOut) :-
        get_code(Stream, 117), get_code(Stream, 108), get_code(Stream, 108),
        get_code(Stream, NextChar), !,
        read_json_value4(Stream, NextChar, [has_value(null,null) | Acc], ValueOut).

% ":"
read_json_value4(Stream, 58, [has_value(string,String) | Acc], ValueOut) :-
        get_code(Stream, Char),
        atom_codes(Name, String),
        !, read_json_value4(Stream, Char, [has_name(Name) | Acc], ValueOut).
read_json_value4(_Stream, 58, _, _ValueOut) :-
        write('encountered ":" but no name previously.~n'), fail.

% "{"
read_json_value4(Stream, 123, Acc, ValueOut) :-
        % write('in_structure\n'),
        get_code(Stream, Char),
        !, read_json_value4(Stream, Char, [in_structure([]) | Acc], ValueOut).

% "}"
read_json_value4(Stream, 125, [has_value(_Ty, Value), has_name(Name), in_structure(S), has_name(Sname) | Acc], ValueOut) :-
        get_code(Stream, Char), %format(" \\}2 has ~p + ~p as ~p~n",[Value, S, Sname]),
        (S = [] -> Structure = [Name = Value]; reverse([(Name = Value) | S], Structure)),
        !, read_json_value4(Stream, Char, [Sname = has_value(structure,Structure) | Acc], ValueOut).

read_json_value4(Stream, 125, [has_value(_Ty, Value), has_name(Name), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char), %format(" \\}3 has ~p + ~p~n",[Value, S]),
        (S = [] -> Structure = [Name = Value]; reverse([(Name = Value) | S], Structure)),
        !, read_json_value4(Stream, Char, [has_value(structure,Structure) | Acc], ValueOut).

read_json_value4(Stream, 125, [Name = Value, in_structure(S), has_name(Sname) | Acc], ValueOut) :-
        get_code(Stream, Char), %format(" \\}3 has ~p + ~p~n",[Value, S]),
        (S = [] -> Structure = [Name = Value]; reverse([(Name = Value) | S], Structure)),
        !, read_json_value4(Stream, Char, [Sname = has_value(structure,Structure) | Acc], ValueOut).

read_json_value4(Stream, 125, [in_structure([]), has_name(Sname) | Acc], ValueOut) :-
        get_code(Stream, Char), %format(" \\}3 has ~p + ~p~n",[Value, S]),
        !, read_json_value4(Stream, Char, [Sname = has_value(structure,[]) | Acc], ValueOut).

read_json_value4(Stream, 125, [Name = Value, in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char), %format(" \\}3 has ~p + ~p~n",[Value, S]),
        (S = [] -> Structure = [Name = Value]; reverse([(Name = Value) | S], Structure)),
        !, read_json_value4(Stream, Char, [has_value(structure,Structure) | Acc], ValueOut).

read_json_value4(_Stream, 125, Acc, _ValueOut) :-
        !, format('encountered "}" but no start of structure previously. acc=~q~n',[Acc]), fail.

% "["
read_json_value4(Stream, 91, Acc, ValueOut) :-
        % write('in_list\n'),
        get_code(Stream, Char),
        read_json_value4(Stream, Char, [in_list([]) | Acc], ValueOut), !.

% "]"
read_json_value4(Stream, 93, [in_list(S), has_name(Name) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [Name = has_value(list,S) | Acc], ValueOut).

read_json_value4(Stream, 93, [LL, in_list(S), has_name(Name) | Acc], ValueOut) :-
        get_code(Stream, Char),
        reverse([LL | S], List), !,
        read_json_value4(Stream, Char, [Name = has_value(list, List) | Acc], ValueOut).

read_json_value4(Stream, 93, [LL, in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char),
        reverse([LL | S], List), !,
        read_json_value4(Stream, Char, [has_value(list, List) | Acc], ValueOut).

read_json_value4(Stream, 93, [in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char),
        reverse(S, List), !,
        read_json_value4(Stream, Char, [has_value(list, List) | Acc], ValueOut).

read_json_value4(_Stream, 93, Acc, _ValueOut) :-
        !, format('encountered "]" but no start of list previously. acc=~q~n',[Acc]), fail.

% "," - commit value
read_json_value4(Stream, 44, [LL, in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_list([LL | S]) | Acc], ValueOut).

read_json_value4(Stream, 44, [N=has_value(Ty,Val), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_structure([N=has_value(Ty,Val) | S]) | Acc], ValueOut).

read_json_value4(Stream, 44, [LL, has_name(N), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_structure([N = LL | S]) | Acc], ValueOut).

read_json_value4(_Stream, 44, Acc, _ValueOut) :-
        !, format('encountered "," but could not add it. acc=~q~n',[Acc]), fail.

% ignore other characters - for debugging
%read_json_value4(Stream, Char, Acc, ValueOut) :-
%        format("  !!! unmatched char: ~d  acc=~q~n", [Char, Acc]),
%        get_code(Stream, NextChar),
%        !, read_json_value4(Stream, NextChar, Acc, ValueOut).

% util
read_txtwhile(Stream, Set, Acc, Result, OutCode) :-
        get_code(Stream, Char),
        ( member(Char, Set) ->
                !, read_txtwhile(Stream, Set, [Char | Acc], Result, OutCode)
        ;
                reverse(Acc, Result), OutCode = Char).


% example1 :-
%         open_string('{ "bool": true, "false": false, "a": 3, "b": [1,2,3] }\n', Stream),
%         toolbox:from_json(Stream, Json),
%         Json = [[bool=true, false=false, a=3, b=[1, 2, 3]]].

json_from_file(Filename, Json) :-
        open(Filename, read, Stream),
        from_json(Stream, Json),
        close(Stream).


% print Json structure

json_print(Json) :-
        json_print2(Json, 0).

% json_print2(X, Indent) :-
%         is_list(X), !,
%         NewIndent is Indent + 2,
%         member(E, X), json_print2(E, NewIndent); true.

json_print2(N=X, Indent) :- !,
        format("\"~a\": ", [N]),
        json_print2(X, Indent), nl.
json_print2(has_value(string, S), _Indent) :- !,
        format("\"~s\"~n", [S]).
json_print2(has_value(boolean, B), _Indent) :- !,
        format("~p~n", [B]).
json_print2(has_value(number, V), _Indent) :- !,
        format("~q~n", [V]).
json_print2(has_value(null, null), _Indent) :- !,
        format("null~n", []).
json_print2(has_value(list, L), Indent) :-
        is_list(L), !,
        nl,
        indent(Indent),
        format("[~n",[]),
        NewIndent is Indent + 2,
        json_print_list(L, NewIndent, 0),
        indent(Indent),
        format("]~n",[]).
json_print2(has_value(structure, S), Indent) :-
        is_list(S), !,
        nl,
        indent(Indent),
        format("{~n",[]),
        NewIndent is Indent + 2,
        json_print_list(S, NewIndent, 0),
        indent(Indent),
        format("}~n",[]).
json_print2(X, _Indent) :-
        number(X), !,
        format("~p",[X]).
json_print2(X, _Indent) :-
        atom(X), !,
        format("~a",[X]).
json_print2(X, _Indent) :-
        list(X), !,
        format("\"~s\"",[X]).

indent(0) :- !.
indent(Indent) :-
        put_char(' '),
        NewIndent is Indent - 1,
        indent(NewIndent).

json_print_list([], _Indent, _) :- !.
json_print_list([A|L], Indent, 0) :- !,
        indent(Indent),
        format("  ",[]), % first element without leading separator
        json_print2(A, Indent),
        NewCount is 1,
        json_print_list(L, Indent, NewCount).
json_print_list([A|L], Indent, Count) :-
        indent(Indent),
        format(", ",[]),
        json_print2(A, Indent),
        NewCount is Count + 1,
        json_print_list(L, Indent, NewCount).


%
% tests
%

% json_print2(test=has_value(number,3), 0).
% json_print2(test=has_value(string, "failed"), 0).
% json_print2(test=has_value(null,null), 0).
% json_print2(test=has_value(boolean,true), 0).

% json_print(test=has_value(list, [1,2,3])).
% json_print(test=has_value(structure, ['one'=1,'two'=has_value(structure, ['some'="more", 'any'=42, 'ids'=[]]),'three'=has_value(list, [3, 9, 81])])).
