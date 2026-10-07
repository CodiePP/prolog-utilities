/*-------------------------------------------------------------------------*/
/* Prolog CGI handling                                                     */
/*                                                                         */
/* Part  : CGI Handling                                                    */
/* File  : common.pl                                                       */
/* Descr.: Helps with reading and writing to/from CGI requests             */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2026 Alexander Diemand                               */
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


info_cgi :- 
        write('Prolog CGI, CGI handling'),nl,
        info_init_cgi,
        info_generate_html_output.


info_init_cgi :-
        %      ^                          ^
        write('init_cgi                   initializes and parses CGI request'),nl.

init_cgi :-  
        read_environment,
        read_cgi_input(Codes),
        atom_codes(Input,Codes),
        open_string(Input,Str),
        current_input(DefInp),
        set_input(Str),
        setup_environment,
        set_input(DefInp),
        cgi_close_string(Str),
        read_cookies.

% read_cgi_input(-Codes)
% the raw request parameters: QUERY_STRING for method GET, otherwise
% CONTENT_LENGTH bytes (or everything up to end of file) from stdin.
% Throws error(resource_error(cgi_input_length(Max)),init_cgi/0) if the
% input is longer than max_input_length/1.
read_cgi_input(Codes) :-
        max_input_length(Max),
        ( getenv('REQUEST_METHOD','GET') ->
            ( getenv('QUERY_STRING',Query) -> atom_codes(Query,Codes) ; Codes = [] )
          ; getenv('CONTENT_LENGTH',LenAtom),
            atom_codes(LenAtom,LenCodes),
            catch(number_codes(Len,LenCodes),_,fail),
            integer(Len), Len >= 0 ->
            check_input_length(Len,Max),
            read_n_codes(Len,Codes)
          ;
            Limit is Max + 1,
            read_n_codes(Limit,Codes)
        ),
        length(Codes,N),
        check_input_length(N,Max).

% max_input_length(-Max)
% maximum length of the request parameters in bytes; the default of 1 MiB
% can be changed with cgi_env(plMaxInput,Max) asserted before init_cgi.
max_input_length(Max) :-
        cgi_env(plMaxInput,Max), integer(Max), !.
max_input_length(1048576).

check_input_length(N,Max) :- N =< Max, !.
check_input_length(_,Max) :-
        throw(error(resource_error(cgi_input_length(Max)),init_cgi/0)).

% read_n_codes(+N,-Codes)
% reads at most N codes from the current input
read_n_codes(0,[]) :- !.
read_n_codes(N,Codes) :-
        get_code(C),
        ( C == -1 ->
            Codes = []
          ;
            Codes = [C|R],
            N1 is N - 1,
            read_n_codes(N1,R)
        ).


% defines the documents content type
content_type(Ctype) :-
        cgi_env('plContentType',Ctype), !.

content_type('text/html'). % the default


% setup_environment
% reads the cgi variable line and sets up predicates with the name:
% cgi_in(<var>,<content>)

setup_environment :-
        read_txtuntil(61,H), % till '='
        filter(H,H1),
        read_txtuntil(38,B), % till '&'
        filter(B,B1),
        make_env(H1,B1).

% read_environment
% reads the shell environment and sets up the cgi_env predicates
read_environment :-
        findall(X,(        member(X,['REMOTE_ADDR','UNIQUE_ID','HOSTNAME','REQUEST_METHOD','HTTP_COOKIE']),
                        getenv(X,Y), 
                        Z =.. ['cgi_env',X,Y], 
                        asserta(Z)), 
                _).


% read_cookies
% checks to find cookies in the httpd environment
read_cookies :-
        cgi_env('HTTP_COOKIE',X),
        read_cookies_aux(X) ; true.

read_cookies_aux(String) :- 
        ( pl_regexp(String, '^(.*); (.+)=(.+);*$', Match) ->
             true
          ;
             pl_regexp(String, '^()(.+)=(.+);*$', Match)
        ),
        %write(Match),nl,
        read_cookies_aux2(Match).

read_cookies_aux2([]) :- !.
read_cookies_aux2([_,B,C0,D0|_]) :-
        %write(C),write('-->'),write(D),nl,
        %string_to_atom(C0,C),
        %string_to_atom(D0,D),
        atom_codes(C,C0),
        atom_codes(D,D0),
        X =.. ['cgi_cookies',C,D],
        asserta(X),
        read_cookies_aux(B).

% make_env(+Head,+Body)
% used by setup_environment to assert the cgi_in predicates
make_env([],[]) :- !.

make_env(H,B) :- 
        atom_codes(X,H),
        atom_codes(Y,B),
        asserta(cgi_in(X,Y)),
        setup_environment.


info_generate_html_output :-
        %      ^                          ^
        write('info_generate_html_output  generates HTML output from file, replacing @..@ with predicates'),nl.

% generate_html_output(+PredicateList,+Filename)
% parses an HTML template file and replaces everything between @..@ with the corresponding content from a predicate given in Predlist
        
generate_html_output(File) :- generate_html_output(['cgi_in'],File). % default in cgi_in
generate_html_output(Predlist,File) :-
        generate_html_output(Predlist,File,[]).
generate_html_output(Predlist,File,Opts) :-
        ( member('no_HTML_header',Opts) -> 
                true
        ;
                output_html_header
        ),
        ( access_file(File,read) ->
            true
          ;
            write('File does not exist '),
            write(File),nl,
            fail
        ),
        open(File, read, Stream),
        current_input(OldCI),
        set_input(Stream),
        parse_html(Predlist),
        close(Stream),
        flush_output,
        set_input(OldCI),
        !.

generate_html_output(_,_,_).  % succeeds always

output_html_header :-
        X =.. ['prepare_cookies'],
        (catch(call(X),_,true) -> true ; true),

        content_type(Ctype),
        output_header('Content-type',Ctype),

        % status
        (cgi_env(plStatus,Status) ->
                output_header('Status',Status)
        ;
                true
        ),
        % pragmas
        (cgi_env(plPragma,Pragma) ->
                output_header('Pragma',Pragma)
        ;
                true
        ),
        % cache control
        (cgi_env(plCacheControl,CacheCtrl) ->
                output_header('Cache-Control',CacheCtrl)
        ;
                true
        ),
        % location
        (cgi_env(plLocation,Loc) ->
                output_header('Location',Loc)
        ;
                true
        ),
        % Modified
        (cgi_env(plModified,Modif) ->
                output_header('Last-Modified',Modif)
        ;
                true
        ),
        nl.

% output_header(+Name,+Value)
% writes a header line; CR and LF are removed from the value so that it
% cannot end the header early or add further headers
output_header(Name,Value) :-
        value_codes(Value,Codes),
        strip_crlf(Codes,Safe),
        atom_codes(SafeValue,Safe),
        format("~a: ~a~n",[Name,SafeValue]).

strip_crlf([],[]).
strip_crlf([C|R],Out) :-
        ( C =:= 13 ; C =:= 10 ), !,
        strip_crlf(R,Out).
strip_crlf([C|R],[C|Out]) :-
        strip_crlf(R,Out).

        % now output everything to debug.file
%        open('debug.file',write,Fstr),
%        current_output(DefOut),
%        set_output(Fstr),
%        listing(cgi_env/2),
%        listing(cgi_in/2),
%        listing(cgi_cookies/2),
%        close(Fstr),
%        set_output(DefOut).
 
%        ( environ('HTTP_COOKIE',Cookie) ->
%             write('Cookie: '),write(Cookie),write('<br>\n'),nl
%          ;
%             true
%        ).

%output_environ :- 
%        setof([X,Y],environ(X,Y),L), write('<pre>'),write(L),write('</pre>'), nl. 


% parse_html(+Predlist)
% reads from the current input and tries to interpret it before dumping to the output
parse_html(Predlist) :-
        get_code(Code),
        parse_html_aux(Predlist,Code).

parse_html_aux(_,-1) :- !.

parse_html_aux(Predlist,92) :-   % a '\' 
        get_code(Char),
        (Char == 123 ->
                put_code(Char)
        ;        put_code(92),put_code(Char)
        ),!,
        parse_html(Predlist).

parse_html_aux(Predlist,Code) :-
        interpret_html(Predlist,Code),
        parse_html(Predlist), !.


% interpret_html(+Code)
% tries to interpret the code from the Stream

interpret_html(_,-1).     % end of stream

interpret_html(_,123) :-   % a '{' call a predicate or ignore
        read_txtuntil(125,String), % until '}'
        atom_codes(Atm,String),
        atom_to_term(Atm, Callable, _),
        catch(call(Callable), Err, output_error(Err)),
        !.

interpret_html(_,123) :- !.  % ignore '{'

% a '@' replace the tag with the predicate/2 2nd param, HTML-escaped;
% '@!name@' writes the value unescaped (only for trusted values)
interpret_html(Predlist,64) :-
        read_txtuntil(64,String),
        ( String = [33|Name] -> Raw = true ; Name = String, Raw = false ),
        atom_codes(Var,Name),
        ( interpret_html_aux(Predlist,Var,Value) ->
            ( Raw == true -> write(Value) ; write_html_escaped(Value) )
          ;
            atom_codes(Tag,String),
            write(Tag)   % if not found, simply copy
        ).

interpret_html(_,Code) :- 
        atom_codes(Var,[Code]),write(Var).  % everything else

% go through the list of predicates that can match
% the string and unify it with predicate(+string,-newstring);
% fails if none of them has a fact for the string
interpret_html_aux([Pred|R],String,NewString) :-
        Callable =.. [Pred,String,NewString],
        ( clause(Callable,true) -> 
            % found a predicate fact
            catch(Callable, Err, output_error(Err))
          ;
            % try next predicate from list
            interpret_html_aux(R,String,NewString)
        ), !.

% output_error(+Err)
% used as a catch in interpret_html/2
output_error(Err) :-
        nl,write('Error'),writeq(Err),nl.

% filter(+String,-String)
% parses the cgi line and changes special characters to ascii codes

%filter(This,New) :- filter_aux(This,New).

filter([],[]) :- !.  % at the end: copy it into the result

filter([13|R],New) :- !, filter(R,New).  % leave CR (13)
filter([10|R],New) :- !, filter(R,New).  % leave LF (10)
filter([43|R],[32|New]) :- !, filter(R,New).  % '+' as a space

filter([37,A,B|R],[NewC|New]) :-  % '%' and two hex digits
        hex_digit(A,XA),
        hex_digit(B,XB), !,
        NewC is XA*16 + XB,
        filter(R,New).

filter([H|R],[H|N]) :- filter(R,N). % otherwise, also a '%' without hex digits

hex_digit(C,X) :- C >= 48, C =< 57, !, X is C - 48.   % 0-9
hex_digit(C,X) :- C >= 65, C =< 70, !, X is C - 55.   % A-F
hex_digit(C,X) :- C >= 97, C =< 102, X is C - 87.     % a-f


% encode(+Codes,-Codes)
% encodes some characters in the code list as HTML chars
encode([],[]).
encode([A|R],Out) :-
        encode_char(A,X),
        append(X,Rest,Out),
        encode(R,Rest).

encode_char(60,Cs) :- !, atom_codes('&lt;',Cs).   % <
encode_char(62,Cs) :- !, atom_codes('&gt;',Cs).   % >
encode_char(38,Cs) :- !, atom_codes('&amp;',Cs).  % &
encode_char(34,Cs) :- !, atom_codes('&quot;',Cs). % "
encode_char(39,Cs) :- !, atom_codes('&#39;',Cs).  % '
encode_char(A,[A]).

% write_html_escaped(+Value)
% writes an atom, number or other term with <>&"' HTML-escaped
write_html_escaped(Value) :-
        value_codes(Value,Codes),
        encode(Codes,Enc),
        atom_codes(Atom,Enc),
        write(Atom).

% value_codes(+Value,-Codes)
% the text of Value as written by write/1
value_codes(Value,Codes) :-
        atom(Value), !,
        atom_codes(Value,Codes).
value_codes(Value,Codes) :-
        number(Value), !,
        number_codes(Value,Codes).
value_codes(Value,Codes) :-
        cgi_term_codes(Value,Codes).
