% Integration tests for the WebSocket predicates against the /ws/...
% endpoints of pl_curl/test/http_fixture.pl. Run with ci/it-curl.sh.
% Env: FIXTURE_PORT (18080).
%
% WebSockets need libcurl >= 8.11.0 built with WebSocket support. Without
% it the test websocket_support fails, unless PL_CURL_WS_OPTIONAL=1 is set,
% and all other tests are skipped.

:- use_module(library(plunit)).
:- use_module(sbcl(curl)).

ws_url(Path, URL) :-
    ( getenv('FIXTURE_PORT', P) -> true ; P = '18080' ),
    atomic_list_concat(['ws://127.0.0.1:', P, Path], URL).

ws_open(Path, Opts, WS) :-
    ws_url(Path, URL),
    pl_curl_ws_open(URL, Opts, WS).

% runs Goal with a connection to Path, always closing it
with_ws(Path, Opts, WS, Goal) :-
    setup_call_cleanup(ws_open(Path, Opts, WS),
                       Goal,
                       catch(pl_curl_ws_close(WS), _, true)).

% fails only if the library itself lacks WebSocket support
ws_available :-
    catch(( ws_open('/ws/echo', [], WS), pl_curl_ws_close(WS) ),
          error(curl_error(Msg), _),
          \+ unsupported(Msg)).

unsupported(Msg) :-
    (   sub_atom(Msg, _, _, _, 'without WebSocket support')
    ;   sub_atom(Msg, _, _, _, 'WebSockets need libcurl')
    ), !.

:- begin_tests(curl_ws_support).

test(websocket_support) :-
    (   ws_available
    ->  true
    ;   getenv('PL_CURL_WS_OPTIONAL', '1')
    ->  print_message(warning, format('libcurl without WebSocket support: WebSocket tests skipped', []))
    ;   fail
    ).

:- end_tests(curl_ws_support).

:- begin_tests(curl_ws_it, [condition(ws_available)]).

% --- messages -------------------------------------------------------------

test(echo_text_as_codes) :-
    with_ws('/ws/echo', [], WS,
            ( pl_curl_ws_send(WS, 'hello'),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == text(`hello`).

test(echo_text_as_string) :-
    with_ws('/ws/echo', [text_as(string)], WS,
            ( pl_curl_ws_send(WS, "a string"),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == text("a string").

test(echo_text_as_atom) :-
    with_ws('/ws/echo', [text_as(atom)], WS,
            ( pl_curl_ws_send(WS, `codes`),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == text(codes).

test(echo_binary) :-
    with_ws('/ws/echo', [], WS,
            ( pl_curl_ws_send(WS, binary([0, 1, 127, 128, 255])),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == binary([0, 1, 127, 128, 255]).

test(messages_in_order) :-
    numlist(1, 20, Ns),
    with_ws('/ws/echo', [text_as(atom)], WS,
            ( forall(member(N, Ns), ( atom_number(A, N), pl_curl_ws_send(WS, A) )),
              findall(A, ( member(_, Ns), pl_curl_ws_recv(WS, 2000, text(A)) ), As) )),
    maplist([N, A]>>atom_number(A, N), Ns, As).

test(empty_message) :-
    with_ws('/ws/echo', [text_as(atom)], WS,
            ( pl_curl_ws_send(WS, ''),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == text('').

test(fragments_are_joined) :-
    with_ws('/ws/fragmented', [text_as(string)], WS,
            pl_curl_ws_recv(WS, 2000, Msg)),
    Msg == text("part1-part2-part3").

test(big_message) :-
    with_ws('/ws/big', [text_as(string)], WS,
            pl_curl_ws_recv(WS, 5000, text(S))),
    string_length(S, 100000).

test(utf8_text_decoded) :-
    with_ws('/ws/unicode', [text_as(atom)], WS,
            pl_curl_ws_recv(WS, 2000, Msg)),
    atom_codes(Expected, [0'G, 0'r, 252, 223, 0'e, 0' , 128512]),
    Msg == text(Expected).

test(utf8_text_sent) :-
    atom_codes(Text, [0'G, 0'r, 252, 223, 0'e, 0' , 128512]),
    with_ws('/ws/echo', [text_as(atom)], WS,
            ( pl_curl_ws_send(WS, Text),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == text(Text).

test(handshake_headers) :-
    with_ws('/ws/headers', [ header('X-Test', 'abc'),
                             user_agent('plu-it-ws/1.0'),
                             text_as(string) ], WS,
            pl_curl_ws_recv(WS, 2000, text(S))),
    split_string(S, "\n", "", Lines),
    memberchk("user_agent=plu-it-ws/1.0", Lines),
    memberchk("x_test=abc", Lines).

% the fixture sends a ping and reports whether libcurl answered it
test(ping_answered) :-
    with_ws('/ws/ping', [text_as(atom)], WS,
            pl_curl_ws_recv(WS, 3000, Msg)),
    Msg == text('pong received').

% --- timeouts ---------------------------------------------------------------

test(recv_timeout) :-
    with_ws('/ws/silent', [], WS,
            ( get_time(T0),
              pl_curl_ws_recv(WS, 300, Msg),
              get_time(T1) )),
    Msg == timeout,
    T1 - T0 >= 0.25,
    T1 - T0 < 2.

test(zero_timeout_polls) :-
    with_ws('/ws/silent', [], WS,
            pl_curl_ws_recv(WS, 0, Msg)),
    Msg == timeout.

% the connection stays usable after a timeout and beyond connect_timeout
test(usable_after_timeouts) :-
    with_ws('/ws/echo', [connect_timeout(1), text_as(atom)], WS,
            ( pl_curl_ws_recv(WS, 1500, timeout),
              pl_curl_ws_send(WS, still_there),
              pl_curl_ws_recv(WS, 2000, Msg) )),
    Msg == text(still_there).

% --- closing ----------------------------------------------------------------

test(server_close) :-
    with_ws('/ws/close', [text_as(atom)], WS,
            pl_curl_ws_recv(WS, 2000, Msg)),
    Msg == close(4001, bye).

test(recv_after_server_close, [throws(error(curl_error(_), context(pl_curl_ws_recv/3, _)))]) :-
    with_ws('/ws/close', [], WS,
            ( pl_curl_ws_recv(WS, 2000, close(_, _)),
              pl_curl_ws_recv(WS, 100, _) )).

test(send_after_server_close, [throws(error(curl_error(_), context(pl_curl_ws_send/2, _)))]) :-
    with_ws('/ws/close', [], WS,
            ( pl_curl_ws_recv(WS, 2000, close(_, _)),
              pl_curl_ws_send(WS, too_late) )).

test(closed_handle_recv, [throws(error(existence_error(curl_websocket, _), _))]) :-
    ws_open('/ws/echo', [], WS),
    pl_curl_ws_close(WS),
    pl_curl_ws_recv(WS, 100, _).

test(closed_handle_close, [throws(error(existence_error(curl_websocket, _), _))]) :-
    ws_open('/ws/echo', [], WS),
    pl_curl_ws_close(WS),
    pl_curl_ws_close(WS).

test(not_a_handle, [throws(error(type_error(curl_websocket, 42), _))]) :-
    pl_curl_ws_recv(42, 100, _).

test(number_is_not_text, [throws(error(type_error(_, 42), _))]) :-
    with_ws('/ws/echo', [], WS,
            pl_curl_ws_send(WS, 42)).

test(closed_handle_prints) :-
    ws_open('/ws/echo', [], WS),
    pl_curl_ws_close(WS),
    format(atom(A), '~p', [WS]),
    sub_atom(A, _, _, _, closed), !.

% --- limits and errors ------------------------------------------------------

test(message_over_limit, [throws(error(curl_error(Msg), context(pl_curl_ws_recv/3, _)))]) :-
    with_ws('/ws/oversize', [max_message(1000)], WS,
            pl_curl_ws_recv(WS, 5000, _)),
    atom(Msg).

test(not_a_websocket_endpoint, [throws(error(curl_error(_), context(pl_curl_ws_open/3, _)))]) :-
    ws_open('/get', [], _).

test(connection_refused, [throws(error(curl_error(_), context(pl_curl_ws_open/3, _)))]) :-
    pl_curl_ws_open('ws://127.0.0.1:1/', [connect_timeout(2)], _).

test(http_scheme_refused, [throws(error(curl_error(_), context(pl_curl_ws_open/3, _)))]) :-
    ( getenv('FIXTURE_PORT', P) -> true ; P = '18080' ),
    atomic_list_concat(['http://127.0.0.1:', P, '/ws/echo'], URL),
    pl_curl_ws_open(URL, [], _).

test(header_crlf_rejected, [throws(error(curl_error(_), context(pl_curl_ws_open/3, _)))]) :-
    ws_open('/ws/echo', [header('X-Test', 'a\r\nX-Other: injected')], _).

test(text_as_invalid, [throws(error(domain_error(text_as, json), _))]) :-
    ws_open('/ws/echo', [text_as(json)], _).

test(options_not_a_list, [throws(error(type_error(list, foo), _))]) :-
    ws_open('/ws/echo', foo, _).

test(timeout_not_integer, [throws(error(type_error(integer, soon), _))]) :-
    with_ws('/ws/echo', [], WS,
            pl_curl_ws_recv(WS, soon, _)).

test(binary_not_bytes, [throws(error(_, _))]) :-
    with_ws('/ws/echo', [], WS,
            pl_curl_ws_send(WS, binary([256]))).

% --- threads ----------------------------------------------------------------

test(connections_in_threads) :-
    numlist(1, 4, Ns),
    maplist([N, T]>>thread_create(
                ( atom_number(Sent, N),
                  with_ws('/ws/echo', [text_as(atom)], WS,
                          ( pl_curl_ws_send(WS, Sent),
                            pl_curl_ws_recv(WS, 2000, text(A)) )),
                  atom_number(A, N) ),
                T, []),
            Ns, Ts),
    maplist([T]>>thread_join(T, true), Ts).

:- end_tests(curl_ws_it).
