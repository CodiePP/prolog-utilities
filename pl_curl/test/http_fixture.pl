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
%
% WebSocket endpoints (ws://127.0.0.1:Port/ws/...):
%   /ws/echo        echoes text and binary messages, closes when the client does
%   /ws/headers     sends one text message: Name=Value lines of the handshake's
%                   user agent and X-Test header, then echoes like /ws/echo
%   /ws/fragmented  sends "part1-part2-part3" as one message in three fragments
%   /ws/big         sends one text message of 100000 'x'
%   /ws/oversize    sends one text message of 5000 'x' (for max_message limits)
%   /ws/unicode     sends the text "Gr\u00FC\u00DFe " followed by U+1F600
%   /ws/close       closes at once with status 4001 and reason "bye"
%   /ws/silent      sends nothing (receive timeouts)
%   /ws/ping        sends a ping, then the text "pong received" once the pong arrives

:- encoding(utf8).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_header)).
:- use_module(library(http/websocket)).

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
:- http_handler(root(ws/echo),       http_upgrade_to_websocket(ws_echo, []),       [spawn([])]).
:- http_handler(root(ws/headers),    ws_headers,                                    [spawn([])]).
:- http_handler(root(ws/fragmented), ws_fragmented,                              [spawn([])]).
:- http_handler(root(ws/big),        http_upgrade_to_websocket(ws_big, []),        [spawn([])]).
:- http_handler(root(ws/oversize),    http_upgrade_to_websocket(ws_oversize, []),    [spawn([])]).
:- http_handler(root(ws/unicode),    http_upgrade_to_websocket(ws_unicode, []),    [spawn([])]).
:- http_handler(root(ws/close),      http_upgrade_to_websocket(ws_close, []),      [spawn([])]).
:- http_handler(root(ws/silent),     http_upgrade_to_websocket(ws_echo, []),       [spawn([])]).
:- http_handler(root(ws/ping),       http_upgrade_to_websocket(ws_ping, []),       [spawn([])]).

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

% --- WebSockets -----------------------------------------------------------

ws_echo(WS) :-
    ws_receive(WS, Msg, [format(string)]),
    (   Msg.opcode == close
    ->  catch(ws_close(WS, 1000, ""), _, true)
    ;   memberchk(Msg.opcode, [text, binary])
    ->  ws_send(WS, Msg),
        ws_echo(WS)
    ;   ws_echo(WS)
    ).

ws_headers(Request) :-
    ( memberchk(user_agent(UA), Request) -> true ; UA = '' ),
    ( memberchk(x_test(XT), Request) -> true ; XT = '' ),
    format(string(Text), "user_agent=~w~nx_test=~w", [UA, XT]),
    http_upgrade_to_websocket(ws_headers_then_echo(Text), [], Request).

ws_headers_then_echo(Text, WS) :-
    ws_send(WS, text(Text)),
    ws_echo(WS).

% library(http/websocket) sends every message as one frame, so this
% handler does the handshake itself and writes the frames by hand: a text
% frame without FIN, a continuation frame without FIN, a final continuation
% frame. Then it waits for the client to close.
ws_fragmented(Request) :-
    memberchk(sec_websocket_key(Key), Request),
    websocket:sec_websocket_accept(_{key:Key}, Accept),
    http_switch_protocol(ws_write_fragments,
                         [ header([ upgrade(websocket),
                                    connection('Upgrade'),
                                    sec_websocket_accept(Accept)
                                  ])
                         ]).

ws_write_fragments(In, Out) :-
    set_stream(Out, encoding(octet)),
    ws_frame(Out, 0x01, "part1-"),       % text, more to come
    ws_frame(Out, 0x00, "part2-"),       % continuation, more to come
    ws_frame(Out, 0x80, "part3"),        % continuation, final
    flush_output(Out),
    set_stream(In, encoding(octet)),
    catch(read_until_eof(In), _, true),
    close(Out, [force(true)]).

ws_frame(Out, Byte0, Text) :-
    string_codes(Text, Payload),
    length(Payload, Len),
    put_byte(Out, Byte0),
    put_byte(Out, Len),                  % unmasked, short payload
    maplist(put_byte(Out), Payload).

read_until_eof(In) :-
    get_byte(In, B),
    ( B == -1 -> true ; read_until_eof(In) ).

ws_big(WS) :-
    ws_send_xs(WS, 100000).

% small enough to sit in the socket buffer: a client that rejects it
% (max_message) and disconnects does not break the server's write
ws_oversize(WS) :-
    ws_send_xs(WS, 5000).

ws_send_xs(WS, N) :-
    length(Cs, N), maplist(=(0'x), Cs), string_codes(S, Cs),
    ws_send(WS, text(S)),
    ws_echo(WS).

ws_unicode(WS) :-
    format(string(S), 'Gr~c~ce ~c', [252, 223, 128512]),
    ws_send(WS, text(S)),
    ws_echo(WS).

ws_close(WS) :-
    ws_close(WS, 4001, "bye").

ws_ping(WS) :-
    ws_send(WS, ping("are you there")),
    ws_receive(WS, Msg, []),
    (   Msg.opcode == pong
    ->  ws_send(WS, text("pong received"))
    ;   ws_send(WS, text(unexpected(Msg.opcode)))
    ),
    ws_echo(WS).

main :-
    current_prolog_flag(argv, Argv),
    ( Argv = [PortAtom|_], atom_number(PortAtom, Port) -> true ; Port = 18080 ),
    http_server(http_dispatch, [port(Port)]),
    format(user_error, 'http_fixture listening on ~w~n', [Port]),
    thread_get_message(_).     % block forever; the caller kills the process

:- initialization(main, main).
