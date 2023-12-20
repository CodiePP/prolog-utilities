/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : Stream Handling                                                 */
/* File  : stream.pl                                                       */
/* Descr.: Helps with reading and writing to/from streams                  */
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

info_stream :- 
        write('Prolog Toolbox, Stream handling'),nl,
        info_read_txtline,
        info_read_binline,
        info_read_txtuntil,
        info_read_binuntil,
        info_write_txtline,
        info_write_binline,
        info_read_n_bytes,
        info_read_n_chars,
        info_read_int,
        info_read_short,
        info_read_double.


% Reads a line from the text stream

info_read_txtline :- 
        %      ^                                ^
        write('read_txtline(String)             reads a line from the current text Stream into String'),nl,
        write('read_txtline(Stream,String)      reads a line from a text Stream into String'),nl.

read_txtline(String) :- 
        current_input(Cinp),
        read_txtline(Cinp,String).

read_txtline(Stream,String) :- 
        get_code(Stream,Char),
        '$read_txtline2'(Stream,Char,String).

'$read_txtline2'(_,-1,[]) :- !.   % end of file
'$read_txtline2'(_,10,[]) :- !.   % end of line
'$read_txtline2'(Stream,13,[]) :- get_code(Stream,_),!.   % end of line 13,10 = CR,LF

'$read_txtline2'(Stream,Char,[Char|Rest]) :- read_txtline(Stream,Rest).


% Reads a line from the binary stream

info_read_binline :- 
        %      ^                                ^
        write('read_binline(Stream,String)      reads a line from a binary Stream into String'),nl.

read_binline(String) :- 
        current_input(Cinp),
        read_binline(Cinp,String).

read_binline(Stream,String) :- 
        get_byte(Stream,Char),
        '$read_binline2'(Stream,Char,String).

% '$read_binline2'(_,-1,[]) :- !.   % end of file
'$read_binline2'(Stream,_,[]) :-  at_end_of_stream(Stream),!.   % end of file
'$read_binline2'(_,10,[]) :- !.   % end of line
'$read_binline2'(Stream,13,[]) :- get_byte(Stream,_),!.   % end of line 13,10 = CR,LF

'$read_binline2'(Stream,Char,[Char|Rest]) :- read_binline(Stream,Rest).


% Read a String from text Stream until character Char occurs
% read_until(+Separator, -String)
% reads a string until the Separator is read

read_txtuntil(Sep,String) :- 
        current_input(Cinp),
        read_txtuntil(Cinp,Sep,String).

read_txtuntil(Stream,Sep,String) :- 
        get_code(Stream,Char),
        '$read_txtuntil_aux'(Stream,0,Char,Sep,[],String).

'$read_txtuntil_aux'(_Stream,_Prev,-1,_Sep,Acc,String) :- % end of file
        reverse(Acc,String), !.
'$read_txtuntil_aux'(_Stream,Prev,C,C,Acc,String) :- % match
        Prev \= 92,  % previous char is not '\\'
        reverse(Acc,String), !.
'$read_txtuntil_aux'(Stream,_Prev,C,Sep,Acc,String) :-
        get_code(Stream,Char),
        '$read_txtuntil_aux'(Stream,C,Char,Sep,[C | Acc],String).

info_read_txtuntil :- 
        %      ^                                ^
        write('read_txtuntil(Sep,String)        reads a line from the current text Stream into String until Sep occurs'),nl,
        write('read_txtuntil(Stream,Sep,String) reads a line from a text Stream into String until Sep occurs'),nl.


% Read a String from binary Stream until character Char occurs
% read_until(+Separator, -String)
% reads a string until the Separator is read

read_binuntil(Sep,String) :- 
        current_input(Cinp),
	read_binuntil(Cinp,Sep,String).

read_binuntil(Stream,Sep,String) :- 
        get_byte(Stream,Char),
        '$read_binuntil_aux'(Stream,Char,Sep,String).

'$read_binuntil_aux'(_,-1,_,[]) :- !.   % end of file
'$read_binuntil_aux'(_,C,C,[]) :- !.
'$read_binuntil_aux'(Stream,C,S,[C|Rest]) :- 
        read_binuntil(Stream,S,Rest).

info_read_binuntil :- 
        %      ^                                ^
        write('read_binuntil(Stream,Sep,String) reads a line from a text Stream into String until Sep occurs'),nl.



% Writes a line to the text stream

write_txtline(String) :- 
        current_output(Coutp),
        write_txtline(Coutp,String).

write_txtline(Stream,[Char|Rest]) :- 
        put_code(Stream,Char),
        write_txtline(Stream,Rest),!.

write_txtline(_,[]).

info_write_txtline :-
        %      ^                                ^
        write('write_txtline(String)            writes a string to the current text stream.'), nl,
        write('write_txtline(Stream,String)     writes a string to the text stream.'), nl.


% Writes a line to the binary stream

write_binline(String) :-
        current_output(Coutp),
	write_binline(Coutp,String).

write_binline(Stream,[Char|Rest]) :- 
	put_byte(Stream,Char),
	write_binline(Stream,Rest),!.

write_binline(_,[]).

info_write_binline :-
        %      ^                                ^
        write('write_binline(Stream,String)     writes a string to the binary stream.'), nl.


% read n bytes from the binary stream
read_n_bytes(Str, N, Res) :-
        '$read_n_bytes2'(Str, N, [], Res).

'$read_n_bytes2'(_, 0, Res, Res) :- !.
'$read_n_bytes2'(Str, N, Tres, Res) :-
        M is N - 1,
        '$read_n_bytes2'(Str, M, [Char|Tres], Res),
        get_byte(Str, Char).

info_read_n_bytes :-
        %      ^                                ^
        write('read_n_bytes(Stream,N,Res)       reads up to N bytes from the binary Stream.'), nl.


% read n characters from the text stream
read_n_chars(Str, N, Res) :-
        '$read_n_chars2'(Str, N, [], Res).

'$read_n_chars2'(_, 0, Res, Res) :- !.
'$read_n_chars2'(Str, N, Tres, Res) :-
        M is N - 1,
        '$read_n_chars2'(Str, M, [Char|Tres], Res),
        get_code(Str, Char).

info_read_n_chars :-
        %      ^                                ^
        write('read_n_chars(Stream,N,Res)       reads up to N chars from the text Stream.'), nl.

% reads a 32 bit integer
read_int_BE(Str, Int) :- 
        get_byte(Str,A),
        get_byte(Str,B),
        get_byte(Str,C),
        get_byte(Str,D),
        Int is D \/ (C << 8) \/ (B << 16) \/ (A << 24).

read_int_LE(Str, Int) :-
        get_byte(Str,A),
        get_byte(Str,B),
        get_byte(Str,C),
        get_byte(Str,D),
        Int is A \/ (B << 8) \/ (C << 16) \/ (D << 24).

info_read_int :-
        %      ^                                ^
        write('read_int_[BE|LE](Stream,Int)     reads a 32 bit integer from the binary Stream.'), nl.

% reads a 16 bit integer
read_short_BE(Str, Int) :- 
        get_byte(Str,A),
        get_byte(Str,B),
        Int is B \/ (A << 8).

read_short_LE(Str, Int) :-
        get_byte(Str,A),
        get_byte(Str,B),
        Int is A \/ (B << 8).

info_read_short :-
        %      ^                                ^
        write('read_short_[BE|LE](Stream,Int)   reads a 16 bit integer from the binary Stream.'), nl.


% reads an IEEE extended double (10 bytes)
read_double_LE(Str,Fl) :-
        get_byte(Str,A),
        get_byte(Str,B),
        get_byte(Str,C),
        get_byte(Str,D),
        get_byte(Str,E),
        get_byte(Str,F),
        get_byte(Str,G),
        get_byte(Str,H),
        get_byte(Str,I),
        get_byte(Str,J),
        Exp is ((A /\ 0x7f) << 8) \/ B,
        HiMan is ( (C << 24) \/
                   (D << 16) \/
                   (E <<  8) \/
                   (F) ),
        LoMan is ( (G << 24) \/
                   (H << 16) \/
                   (I <<  8) \/
                   (J) ),
        Exponent1 is Exp - 16383 - 31,
        Res1 is (2.0 ** Exponent1)*HiMan,
        Exponent2 is Exponent1 - 32,
        Res2 is (2.0 ** Exponent2)*LoMan,
        Sign is (A /\ 0x80),
        ( Sign = 0 ->
                Fl is Res1+Res2
        ;
                Fl is -Res1-Res2
        ).
        
info_read_double :-
        %      ^                                ^
        write('read_double_[BE|LE](Stream,Res)  reads a double in ieee extended format from the binary Stream.'), nl.


