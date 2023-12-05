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
        write('from_json(Stream,JsonPairList)   reads from Stream and returns the structure'),nl.

from_json(Stream, Json) :-
        rec_from_json(Stream, [], Json).

rec_from_json(Stream, Acc, JsonOut) :-
        read_json_value(Stream, Value),
        ( Value = [] -> [JsonOut] = Acc
        ; rec_from_json(Stream, [Value | Acc], JsonOut)).

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
        get_code(Stream, Char),
        read_json_value4(Stream, Char, [has_value(string,String) | Acc], ValueOut), !.

% [+-0123456789.]
read_json_value4(Stream, Char, Acc, ValueOut) :-
        member(Char, [43,45,48,49,50,51,52,53,54,55,56,57,46]), !, % [+-0123456789.]
        read_txtwhile(Stream, [43,45,48,49,50,51,52,53,54,55,56,57,46], [Char], NumCodes, NextChar),
        number_codes(Number, NumCodes),
        read_json_value4(Stream, NextChar, [has_value(number,Number) | Acc], ValueOut), !.

% false | true
read_json_value4(Stream, Char, Acc, ValueOut) :-
        member(Char, [102, 97, 108, 115, 101, 116, 114, 117]), !,
        read_txtwhile(Stream, [102, 97, 108, 115, 101, 116, 114, 117], [Char], BoolCodes, NextChar),
        atom_codes(Bool, BoolCodes),
        (member(Bool, ['false', 'true']); format("boolean should be false|true, but got: ~q~n", [Bool]), fail), !,
        read_json_value4(Stream, NextChar, [has_value(boolean,Bool) | Acc], ValueOut), !.

% ":"
read_json_value4(Stream, 58, [has_value(string,String) | Acc], ValueOut) :-
        get_code(Stream, Char),
        atom_codes(Name, String),
        read_json_value4(Stream, Char, [has_name(Name) | Acc], ValueOut), !.
read_json_value4(_Stream, 58, _, _ValueOut) :-
        write('encountered ":" but no name previously.~n'), fail.

% "{"
read_json_value4(Stream, 123, Acc, ValueOut) :-
        % write('in_structure\n'),
        get_code(Stream, Char),
        read_json_value4(Stream, Char, [in_structure([]) | Acc], ValueOut), !.

% "}"
read_json_value4(Stream, 125, [has_value(_Ty, Value), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char),
        (S = [] -> Structure = Value; reverse([Value | S], Structure)),
        read_json_value4(Stream, Char, [has_value(structure,Structure) | Acc], ValueOut), !.

read_json_value4(Stream, 125, [has_value(_Ty, Value), has_name(Name), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char),
        (S = [] -> Structure = (Name = Value); reverse([(Name = Value) | S], Structure)),
        read_json_value4(Stream, Char, [has_value(structure,Structure) | Acc], ValueOut), !.

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
        read_json_value4(Stream, Char, [has_value(list,Name = S) | Acc], ValueOut).

read_json_value4(Stream, 93, [in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [has_value(list, _ = S) | Acc], ValueOut).

read_json_value4(Stream, 93, [has_value(_Ty, Value), in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char),
        reverse([Value | S], List), !,
        read_json_value4(Stream, Char, [has_value(list, List) | Acc], ValueOut).

read_json_value4(Stream, 93, [has_value(_Ty, Value), has_name(Name), in_list(S) | Acc], ValueOut) :-
        write("we should not get here - lists have no named entities!"),
        get_code(Stream, Char),
        reverse([Value | S], List), !,
        read_json_value4(Stream, Char, [has_value(list, Name = List) | Acc], ValueOut).

read_json_value4(Stream, 93, [LL, in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char),
        reverse([LL | S], List), !,
        read_json_value4(Stream, Char, [has_value(list, List) | Acc], ValueOut).

read_json_value4(_Stream, 93, _Acc, _ValueOut) :-
        !, write('encountered "]" but no start of list previously.~n'), fail.

% "," - commit value
read_json_value4(Stream, 44, [has_value(_Ty,Val), in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_list([Val | S]) | Acc], ValueOut).

read_json_value4(Stream, 44, [LL, in_list(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_list([LL | S]) | Acc], ValueOut).

read_json_value4(Stream, 44, [has_value(_Ty,Val), has_name(N), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_structure([N = Val | S]) | Acc], ValueOut).        

read_json_value4(Stream, 44, [LL, has_name(N), in_structure(S) | Acc], ValueOut) :-
        get_code(Stream, Char), !,
        read_json_value4(Stream, Char, [in_structure([N = LL | S]) | Acc], ValueOut).        

read_json_value4(_Stream, 44, _Acc, _ValueOut) :-
        !, write('encountered "," but could not add it.~n'), fail.

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