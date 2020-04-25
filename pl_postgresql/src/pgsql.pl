/*-------------------------------------------------------------------------*/
/* Prolog Interface to PostgreSQL                                          */
/*                                                                         */
/* File  : pgsql.pl                                                        */
/* Descr.:                                                                 */
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

:- module(pgsql, [ pl_encode/2
                 , pl_decode/2
                 , pl_pgsql_connect/1
                 , pl_pgsql_connect/6
                 , pl_pgsql_disconnect/1
                 , pl_pgsql_query/2
                 , pl_pgsql_query/3
                 ]).

:- use_foreign_library(sbcl('plpgsql')).

% encode(+String,-String)
% encodes some characters in the string 
pl_encode(In,Out) :-
        '$pl_encode2'(In,[],Out).
'$pl_encode2'([],Out,Out) :- !.
'$pl_encode2'([A|R],Curr,Out) :-
	once('$pl_encode_char'(A,X)),
	append(Curr,X,Now),
	'$pl_encode2'(R,Now,Out).

'$pl_encode_char'(A,[A]) :-
	A>=65,A=<90,!. % A-Z
'$pl_encode_char'(A,[A]) :-
	A>=97,A=<122,!. % a-z
'$pl_encode_char'(A,[A]) :-
	A>=48,A=<57,!. % 0-9
'$pl_encode_char'(A,B) :-
        A<16,
	sformat(Q,'%0~16r',[A]), % everything else <16
	atom_codes(Q,B),!.
'$pl_encode_char'(A,B) :- 
	sformat(Q,'%~16r',[A]), % everything else >=16
	atom_codes(Q,B),!.

pl_safestring(In,Out) :-
        '$pl_safestring2'(In,[],Out).
'$pl_safestring2'([],Out,Out) :- !.
'$pl_safestring2'([A|R],Curr,Out) :-
	once('$pl_safe_char'(A,X)),
	append(Curr,X,Now),
	'$pl_safestring2'(R,Now,Out).
'$pl_safe_char'(39,"\\'"). % '
'$pl_safe_char'(92,"\\\\"). % \ 
'$pl_safe_char'(A,[A]).


% pl_decode(+String,-String)
% decodes some characters in the string 
pl_decode(In,Out) :-
        '$pl_decode2'(In,[],Out).

'$pl_decode2'([],In,Out) :- 
	reverse(In,Out),!.
'$pl_decode2'([37,A,B|R],Curr,Out) :- % encoded character
	'$pl_decode_char'(A,B,X),
	%append(Curr,[X],Now),!,
	'$pl_decode2'(R,[X|Curr],Out),!.
'$pl_decode2'([A|R],Curr,Out) :- 
	%append(Curr,[A],Now),!,
	'$pl_decode2'(R,[A|Curr],Out).

'$pl_decode_char'(A,B,X) :-
	'$pl_decode_char2'(A,M),
	'$pl_decode_char2'(B,N),
	X is M * 16 + N.

'$pl_decode_char2'(A,X) :-
	A>=65,A=<70, % A-F
	X is A - 55, !.
'$pl_decode_char2'(A,X) :-
	A>=97,A=<102, % a-f
	X is A - 87, !.
'$pl_decode_char2'(A,X) :-
	A>=48,A=<57, % 0-9
	X is A - 48, !.
'$pl_decode_char2'(_,63).  % everything else = '?'


