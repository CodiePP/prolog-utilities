% Small HTTP server used by the pl_curl integration tests (SWI-Prolog only).
%
%   swipl pl_curl/test/http_fixture.pl [Port]        (default port 18080)
%
% Endpoints:
%   /get?...        200, JSON {"args": {...}, "headers": {...}} echoing what was received
%                   (header names lower-case, '-' replaced by '_')
%   /status/N       answers with status N and an empty text body
%   /redirect       303 to /get
%   /slow           answers after 5 seconds (timeout tests)
%   /utf8           text/plain; charset=UTF-8 body "Gr\u00FC\u00DFe" followed by U+1F600 (smiley)
%   /loop           303 to itself (redirect limit)
%   /big            text/plain body of 100000 bytes (body size limit)
%   /file           302 to file:///etc/passwd (redirect protocol restriction)
%   /conn           text/plain id of the TCP connection (keep-alive tests)
%   /binary         application/octet-stream body: bytes 97, 0, 98, 255

:- encoding(utf8).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_header)).

:- http_handler(root(get),      handle_get,      []).
:- http_handler(root(status),   handle_status,   [prefix]).
:- http_handler(root(redirect), handle_redirect, []).
:- http_handler(root(slow),     handle_slow,     []).
:- http_handler(root(utf8),     handle_utf8,     []).
:- http_handler(root(loop),     handle_loop,     []).
:- http_handler(root(big),      handle_big,      []).
:- http_handler(root(file),     handle_file,     []).
:- http_handler(root(conn),     handle_conn,     []).
:- http_handler(root(binary),   handle_binary,   []).

handle_get(Request) :-
    ( memberchk(search(Search), Request) -> true ; Search = [] ),
    findall(N-V, member(N=V, Search), ArgPairs),
    dict_pairs(Args, _, ArgPairs),
    findall(Name-Value,
            ( member(Header, Request),
              Header =.. [Name, Value],
              request_header(Name),
              atomic(Value) ),
            HeaderPairs),
    dict_pairs(Headers, _, HeaderPairs),
    reply_json_dict(_{args: Args, headers: Headers}).

request_header(host).
request_header(user_agent).
request_header(accept).
request_header(authorization).
request_header(x_test).
request_header(x_other).

handle_status(Request) :-
    memberchk(path_info(Path), Request),
    atom_concat('/', CodeAtom, Path),
    atom_number(CodeAtom, Code),
    format('Status: ~d~n', [Code]),
    format('Content-type: text/plain~n~n').

handle_redirect(Request) :-
    http_redirect(see_other, root(get), Request).

handle_slow(_Request) :-
    sleep(5),
    format('Content-type: text/plain~n~n'),
    format('late~n').

handle_utf8(_Request) :-
    format('Content-type: text/plain; charset=UTF-8~n~n'),
    format('Gr~c~ce ~c', [252, 223, 128512]).

handle_loop(Request) :-
    http_redirect(see_other, root(loop), Request).

handle_big(_Request) :-
    format('Content-type: text/plain~n~n'),
    forall(between(1, 100000, _), put_char(x)).

handle_file(_Request) :-
    format('Status: 302~n'),
    format('Location: file:///etc/passwd~n'),
    format('Content-type: text/plain~n~n').

% a new connection has a new input stream, which gets a new alias
handle_conn(Request) :-
    memberchk(input(In), Request),
    (   stream_property(In, alias(Id))
    ->  true
    ;   flag(fixture_conn, N, N + 1),
        atom_concat(conn, N, Id),
        set_stream(In, alias(Id))
    ),
    format('Content-type: text/plain~n~n'),
    format('~w', [Id]).

handle_binary(_Request) :-
    format('Content-type: application/octet-stream~n~n'),
    set_stream(current_output, encoding(octet)),
    format('~s', [[97, 0, 98, 255]]).

main :-
    current_prolog_flag(argv, Argv),
    ( Argv = [PortAtom|_], atom_number(PortAtom, Port) -> true ; Port = 18080 ),
    http_server(http_dispatch, [port(Port)]),
    format(user_error, 'http_fixture listening on ~w~n', [Port]),
    thread_get_message(_).     % block forever; the caller kills the process

:- initialization(main, main).
