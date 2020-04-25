/*-------------------------------------------------------------------------*/
/* Prolog CGI handling                                                     */
/*                                                                         */
/* Part  : CGI Handling                                                    */
/* File  : cgi.pl                                                          */
/* Descr.: Helps with reading and writing to/from CGI requests             */
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

:- module(cgi, [
        init_cgi/0,
        generate_html_output/1,
        generate_html_output/2
    ]).

% needs read_txtuntil from toolbox
:- use_module(sbcl(toolbox), [read_txtuntil/2]).
:- use_module(sbcl(regexp)).

:- dynamic(cgi_env/2).        % where we store the environment
:- dynamic(cgi_in/2).         % keeps the content of the cgi variables
:- dynamic(cgi_cookies/2).    % keeps the content of the cookies


info_cgi :- 
        write('Prolog CGI, CGI handling'),nl,
        info_init_cgi,
        info_generate_html_output.


info_init_cgi :-
        %      ^                          ^
        write('init_cgi                   initializes and parses CGI request'),nl.

init_cgi :-  
        read_environment,
        current_input(DefInp),
        ( getenv('REQUEST_METHOD','GET'),getenv('QUERY_STRING',Query), Query \== '' ->
            % method GET in environment variable QUERY_STRING
            %open_input_atom_stream(Query,Str), % load from environment variable
	    atom_concat('echo "',Query, Cmd1),
	    atom_concat(Cmd1,'"',Cmd),
	    open(pipe(Cmd), read, Str, []),
            set_input(Str),
            true
          ;
            % method POST in stdin
            true
        ),
        setup_environment,
        set_input(DefInp),
        read_cookies.
        

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
        findall(X,(	member(X,['REMOTE_ADDR','UNIQUE_ID','HOSTNAME','REQUEST_METHOD','HTTP_COOKIE']),
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
        ( regexp:pl_regexp(String, '^(.*); (.+)=(.+);*$', Match) ->
             true
          ;
             regexp:pl_regexp(String, '^()(.+)=(.+);*$', Match)
        ),
        %write(Match),nl,
        read_cookies_aux2(Match).

read_cookies_aux2([]) :- !.
read_cookies_aux2([_,B,C0,D0|_]) :-
        %write(C),write('-->'),write(D),nl,
	string_to_atom(C0,C),
	string_to_atom(D0,D),
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
        format("Content-type: ~a~n",[Ctype]),

	% status
	(cgi_env(plStatus,Status) ->
		format("Status: ~a~n",[Status])
	;
		true
	),
	% pragmas
	(cgi_env(plPragma,Pragma) ->
		format("Pragma: ~a~n",[Pragma])
	;
		true
	),
	% cache control
	(cgi_env(plCacheControl,CacheCtrl) ->
		format("Cache-Control: ~a~n",[CacheCtrl])
	;
		true
	),
	% location
	(cgi_env(plLocation,Loc) ->
		format("Location: ~a~n",[Loc])
	;
		true
	),
	% Modified
	(cgi_env(plModified,Modif) ->
		format("Last-Modified: ~a~n",[Modif])
	;
		true
	),
	nl.

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
	;	put_code(92),put_code(Char)
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

interpret_html(Predlist,64) :-   % a '@' replace the tag with the predicate/2 2nd param
        read_txtuntil(64,String),
        atom_codes(Var,String),
        interpret_html_aux(Predlist,Var,OutputString),
        write(OutputString).

interpret_html(_,Code) :- 
	atom_codes(Var,[Code]),write(Var).  % everything else

interpret_html_aux([],String,String) :- !. % if not found, simply copy

% go through the list of predicates that can match
% the string and unify it with predicate(+string,-newstring)
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

filter([],[]).  % at the end: copy it into the result

filter([13|R],New) :- filter(R,New).  % leave CR (13)
filter([10|R],New) :- filter(R,New).  % leave LF (10)
filter([43|R],[32|New]) :- filter(R,New).  % '+' as a space

filter([37,A,B|R],[NewC|New]) :-  % '%' and hex identifier
        ( A >= 97 ->
           XA is A - 32
          ;
           XA = A
        ),
        ( B >= 97 ->
           XB is B - 32
          ;
           XB = B
        ),
        ( XA >= 65 -> 
             X1 is (XA - 55)*16
          ;
             X1 is (XA - 48)*16
        ),
        ( XB >= 65 ->
             X2 is XB - 55
         ;
             X2 is XB - 48
        ),
        NewC is X1+X2,
        filter(R,New).

filter([H|R],[H|N]) :- filter(R,N). % otherwise


% encode(+String,-String)
% encodes some characters in the string as HTML chars
encode(In,Out) :-
	encode(In,[],Out).
encode([],Out,Out).
encode([A|R],Curr,Out) :-
	once(encode_char(A,X)),
	append(Curr,X,Now),
	encode(R,Now,Out).
	
encode_char(60,"&lt;"). % <
encode_char(62,"&gt;"). % >
encode_char(38,"&amp;"). % &
encode_char(34,"&quot;"). % "
encode_char(39,"&#39;"). % '
encode_char(A,[A]).
