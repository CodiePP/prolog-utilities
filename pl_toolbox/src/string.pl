/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : String Handling                                                 */
/* File  : string.pl                                                       */
/* Descr.: Helps with strings                                              */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2020 Alexander Diemand                               */
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

info_string :- write('Prolog Toolbox, String handling'),nl,
               info_removesublist_3,
               info_sub_string_4,
               info_list2string_2,
               info_list2string_3,
               info_string2list_2,
               info_string2list_3,
               info_split_4,
               info_remove_leading_3,
               info_remove_trailing_3,
	       info_skip_3,
	       info_align_left_3,
	       info_align_right_3,
	       info_lower_case_2,
	       info_upper_case_2.



%
%
                               %                                  %
info_removesublist_3 :- write('removesublist(ListIn,SubL,ListOut) Removes all occurencies of SubL in ListIn'),nl.

removesublist(ListIn,SubL,ListOut) :-
	removesublist_aux(ListIn,SubL,[],ListOut).

removesublist_aux([],_,In,Out) :- 
	reverse(In,Out),!.
removesublist_aux(List,SubL,In,ListOut) :-
	append(SubL,R,List),
	removesublist_aux(R,SubL,In,ListOut),!.
removesublist_aux([A|R],SubL,In,ListOut) :-
	removesublist_aux(R,SubL,[A|In],ListOut),!.
	

% Creates a string representation of all elements of the list
% by default the separater introduced between elements is space.

                             %                                  %
info_list2string_2 :- write('list2string(List,String)           makes a string from a list separated by " "'),nl.
info_list2string_3 :- write('list2string(List,Sep,String)       makes a string from a list separated by Sep'),nl.

list2string(List,String) :-
	list2string(List,[32],String).
list2string(List,Sep,String) :-
	list2string_aux(List,Sep,[],String).

list2string_aux([],_,String,String) :- !.
list2string_aux([A|R],Sep,In,String) :-
	format(Tgt,'~p',[A]),
  %atom_codes(Tgt,ACodes),
	( In == [] ->
		S1 = In
	;
		append(In,Sep,S1)
	),
	append(S1,ACodes,Out),
	list2string_aux(R,Sep,Out,String).




% Parses a string and creates a list containing all tokens
% can accept the seperating char

                             %                                  %
info_string2list_2 :- write('string2list(String,Lres)           makes a list of tokens from string by " "'),nl.
info_string2list_3 :- write('string2list(String,Sep,Lres)       makes a list of tokens from string by Sep'),nl.

string2list(String,Lres) :- string2list(String,32,Lres).

string2list(Str,Sep,Lres) :- string2list_aux(Str,Sep,[],Lres).

string2list_aux([],_,A,R) :- reverse(A,R),!.

string2list_aux([Sep|Str],Sep,A,R) :- string2list_aux(Str,Sep,A,R),!.
string2list_aux(Str,Sep,A,R) :- ( split(Str,Sep,S1,S2) ->
                                        atom_codes(X,S1)
                                  ;
                                        % the last one
                                        atom_codes(X,Str)
                                ),
                                string2list_aux(S2,Sep,[X|A],R).

% splits a string into 2 substrings at Separator

                       %                                  %
info_split_4 :- write('split(Str,Char,Res1,Res2)          splits at first Char into Res1 and rest to Res2'),nl.

split(Str,Sep,Res1,Res2) :- split_aux(Str,Sep,[],[],Res1,Res2), !.

split_aux([SH|ST],PH,A1,A2,R1,R2) :-              % fill first string
                SH \== PH, split_aux(ST,PH,[SH|A1],A2,R1,R2).

split_aux([SH|ST],PH,A1,A2,R1,R2) :-              % fill rest into second string
                SH == PH, split_aux2(ST,PH,A1,A2,R1,R2).

split_aux2([],_,A1,A2,R1,R2) :-                     % copy acc to result
                reverse(A1,R1),reverse(A2,R2).

                                    % continue till end
split_aux2([SH|ST],PH,A1,A2,R1,R2) :- split_aux2(ST,PH,A1,[SH|A2],R1,R2).


% removes trailing characters
% uses remove_leading/3
                                 %                                  %
info_remove_trailing_3 :- write('remove_trailing(Str,Char,Res)      removes trailing Chars from Str, always true'),nl.

remove_trailing(Str,Sep,Res) :- 
        reverse(Str,Str2),
        remove_leading(Str2,Sep,Res1),
        reverse(Res1,Res),!.

% removes leading characters
% always succeeds. if there is no leading chars to wipe away, the same list is returned
                                %                                  %
info_remove_leading_3 :- write('remove_leading(Str,Char,Res)       removes leading Chars from Str, always true'),nl.

remove_leading(Str,Sep,Res) :- remove_leading_acc(Str,Sep,Res), !.

remove_leading_acc([],_,[]). % might happen that we wipe away all of them
remove_leading_acc([A|R],Sep,[A|R]) :- Sep \== A.  % stop here
remove_leading_acc([A|R],A,Res) :-
        remove_leading_acc(R,A,Res).


% extracts a substring
                            %                                  %
info_sub_string_4 :- write('sub_string(Str,From,To,Res)        extracts substring From position To from Str'),nl.

sub_string(Str,From,To,Res) :-
        From =< To,
        From >= 0,
        length(Str,L),
        To =< L,
        '$substring'(Str,From,To,0,[],Res).

% last
'$substring'([A|_],_,To,To,Res,Res2) :-
        append(Res,[A],Res2),
        !.
% not yet in range, move on
'$substring'([_|Str],From,To,Act,Curr,Res) :-
        From > Act,
        NewAct is Act+1,
        '$substring'(Str,From,To,NewAct,Curr,Res),
        !.
% copy char and move on
'$substring'([A|R],From,To,Act,Curr,Res) :-
        From =< Act,
        Act < To,
        NewAct is Act+1,
        append(Curr,[A],NewCurr),
        '$substring'(R,From,To,NewAct,NewCurr,Res),
        !.


                           %                                  %
info_align_left_3:- write('align_left(Str,Width,Res)          aligns Str to the left, appends spaces'),nl.

align_left(In,Width,Out) :-
	'$align_left'(In,Width,0,[],Out).
'$align_left'(_,Width,Width,RevRes,Res) :- 
	reverse(RevRes,Res),!.
'$align_left'([],Width,TWidth,Rest,Res) :-
	NewTW is TWidth+1,
	'$align_left'([],Width,NewTW,[32|Rest],Res),!.
'$align_left'([A|R],Width,TWidth,Rest,Res) :-
	NewTW is TWidth+1,
	'$align_left'(R,Width,NewTW,[A|Rest],Res).



                            %                                  %
info_align_right_3:- write('align_right(Str,Width,Res)         aligns Str to the right, fills with spaces'),nl.

align_right(In,Width,Out) :-
	length(In,L),
	LSpaces is Width-L, LSpaces > 0,
	align_left([],LSpaces,Spaces),
	append(Spaces,In,Out),!.
align_right(In,Width,Out) :-
	length(In,L),
	Start is L-Width,
	skip(In,Start,Out).



                     %                                  %
info_skip_3:- write('skip(Str,Num,Res)                  skips Num chars in Str and returns as Res'),nl.

skip(In,0,In) :- !.
skip([_|R],Start,Out) :-
        NewTS is Start-1,
	skip(R,NewTS,Out).
		        

                            %                                  %
info_lower_case_2 :- write('lower_case(Str,LowerS)             changes Str to lowercase'),nl.

lower_case(InStr,OutStr) :-
	'$lower_case'(InStr,[],OutStr).
'$lower_case'([],OutStr,OutStr) :- !.
'$lower_case'([A|R],In,OutStr) :-
	(A >= 65, A =< 90 ->
		B is A + 32
	;
		B = A
	),
	append(In,[B],In2),
	'$lower_case'(R,In2,OutStr).
                            %                                  %
info_upper_case_2 :- write('upper_case(Str,UpperS)             changes Str to uppercase'),nl.

upper_case(InStr,OutStr) :-
	'$upper_case'(InStr,[],OutStr).
'$upper_case'([],OutStr,OutStr) :- !.
'$upper_case'([A|R],In,OutStr) :-
	(A =< 122, A >= 97 ->
		B is A - 32
	;
		B = A
	),
	append(In,[B],In2),
	'$upper_case'(R,In2,OutStr).
