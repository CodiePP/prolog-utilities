/* WebSocket integration tests for the GNU Prolog bridge, against the /ws/...
 * endpoints of pl_curl/test/http_fixture.pl. Built and run by ci/it-curl.sh:
 *
 *   gplc -o it_curl_ws_gp pl_curl/test/it_curl_ws_gp.pl \
 *        pl_curl/libplcurl-$(uname -s).a -L '-lcurl -pthread'
 *   FIXTURE_PORT=18080 ./it_curl_ws_gp
 *
 * Exits with status 1 if a test fails. GNU Prolog has no plunit: each test
 * is a goal that must succeed; expected exceptions are checked with catch/3.
 */

:- initialization(main).

main :-
    findall(T, test(T, _), Tests),
    run(Tests, 0, Failed),
    length(Tests, N),
    (   Failed =:= 0
    ->  format("GNU Prolog WebSocket tests: all ~d passed~n", [N]),
        halt(0)
    ;   format("GNU Prolog WebSocket tests: ~d of ~d failed~n", [Failed, N]),
        halt(1)
    ).

run([], F, F).
run([T|Ts], F0, F) :-
    test(T, Goal),
    (   catch(Goal, E, (format("~a: exception ~w~n", [T, E]), fail))
    ->  F1 = F0
    ;   format("FAILED: ~a~n", [T]),
        F1 is F0 + 1
    ),
    run(Ts, F1, F).

ws_url(Path, URL) :-
    (   environ('FIXTURE_PORT', P) -> true ; P = '18080' ),
    atom_concat('ws://127.0.0.1:', P, U0),
    atom_concat(U0, Path, URL).

ws_open(Path, Opts, WS) :-
    ws_url(Path, URL),
    pl_curl_ws_open(URL, Opts, WS).

% Goal with a connection to Path; closed afterwards whether Goal succeeds,
% fails or raises
with_ws(Path, Opts, WS, Goal) :-
    ws_open(Path, Opts, WS),
    catch(Goal, E, true),
    (   catch(pl_curl_ws_close(WS), _, true) -> true ; true ),
    (   var(E) -> true ; throw(E) ).

% raises(Goal, Pattern): Goal raises an exception unifying with Pattern
raises(Goal, Pattern) :-
    catch((Goal, Raised = no), E, Raised = yes(E)),
    Raised = yes(E),
    E = Pattern.

test(echo_text_as_codes,
     ( with_ws('/ws/echo', [], WS,
               ( pl_curl_ws_send(WS, hello),
                 pl_curl_ws_recv(WS, 2000, Msg) )),
       atom_codes(hello, Codes),
       Msg == text(Codes) )).

test(echo_text_as_atom,
     ( with_ws('/ws/echo', [text_as(atom)], WS,
               ( pl_curl_ws_send(WS, "codes"),
                 pl_curl_ws_recv(WS, 2000, Msg) )),
       Msg == text(codes) )).

test(echo_binary,
     ( with_ws('/ws/echo', [], WS,
               ( pl_curl_ws_send(WS, binary([0, 1, 127, 128, 255])),
                 pl_curl_ws_recv(WS, 2000, Msg) )),
       Msg == binary([0, 1, 127, 128, 255]) )).

test(fragments_are_joined,
     ( with_ws('/ws/fragmented', [text_as(atom)], WS,
               pl_curl_ws_recv(WS, 2000, Msg)),
       Msg == text('part1-part2-part3') )).

test(big_message,
     ( with_ws('/ws/big', [], WS,
               pl_curl_ws_recv(WS, 5000, text(Codes))),
       length(Codes, 100000) )).

% no Unicode in GNU Prolog: one code per UTF-8 byte
test(utf8_as_bytes,
     ( with_ws('/ws/unicode', [], WS,
               pl_curl_ws_recv(WS, 2000, Msg)),
       Msg == text([0'G, 0'r, 195, 188, 195, 159, 0'e, 0' , 240, 159, 152, 128]) )).

test(handshake_headers,
     ( with_ws('/ws/headers', [header('X-Test', abc), user_agent('plu-gp/1.0'), text_as(atom)], WS,
               pl_curl_ws_recv(WS, 2000, text(A))),
       sub_atom(A, _, _, _, 'user_agent=plu-gp/1.0'),
       sub_atom(A, _, _, _, 'x_test=abc') )).

test(ping_answered,
     ( with_ws('/ws/ping', [text_as(atom)], WS,
               pl_curl_ws_recv(WS, 3000, Msg)),
       Msg == text('pong received') )).

test(recv_timeout,
     ( with_ws('/ws/silent', [], WS,
               pl_curl_ws_recv(WS, 300, Msg)),
       Msg == timeout )).

test(server_close,
     ( with_ws('/ws/close', [text_as(atom)], WS,
               pl_curl_ws_recv(WS, 2000, Msg)),
       Msg == close(4001, bye) )).

test(recv_after_server_close,
     raises(with_ws('/ws/close', [], WS,
                    ( pl_curl_ws_recv(WS, 2000, close(_, _)),
                      pl_curl_ws_recv(WS, 100, _) )),
            error(curl_error(_), context(pl_curl_ws_recv/3, _)))).

test(closed_handle,
     ( ws_open('/ws/echo', [], WS),
       pl_curl_ws_close(WS),
       raises(pl_curl_ws_recv(WS, 100, _),
              error(existence_error(curl_websocket, WS), _)) )).

test(handles_not_reused,
     ( ws_open('/ws/echo', [], W1),
       pl_curl_ws_close(W1),
       ws_open('/ws/echo', [], W2),
       pl_curl_ws_close(W2),
       W1 \== W2 )).

test(not_a_handle,
     raises(pl_curl_ws_recv(foo, 100, _),
            error(type_error(curl_websocket, foo), _))).

test(unknown_handle,
     raises(pl_curl_ws_recv(999999, 100, _),
            error(type_error(curl_websocket, 999999), _))).

test(message_over_limit,
     raises(with_ws('/ws/oversize', [max_message(1000)], WS,
                    pl_curl_ws_recv(WS, 5000, _)),
            error(curl_error(_), context(pl_curl_ws_recv/3, _)))).

test(not_a_websocket_endpoint,
     raises(ws_open('/get', [], _),
            error(curl_error(_), context(pl_curl_ws_open/3, _)))).

test(header_crlf_rejected,
     raises(ws_open('/ws/echo', [header('X-Test', 'a\r\nX-Other: injected')], _),
            error(curl_error(_), context(pl_curl_ws_open/3, _)))).

test(text_as_invalid,
     raises(ws_open('/ws/echo', [text_as(json)], _),
            error(domain_error(text_as, json), _))).

test(number_is_not_text,
     raises(with_ws('/ws/echo', [], WS, pl_curl_ws_send(WS, 42)),
            error(type_error(text, 42), _))).

test(byte_out_of_range,
     raises(with_ws('/ws/echo', [], WS, pl_curl_ws_send(WS, binary([256]))),
            error(type_error(byte, 256), _))).

% many connections: no handle, memory or descriptor leaks that stop it
test(many_connections,
     ( between(1, 200, _),
       with_ws('/ws/echo', [text_as(atom)], WS,
               ( pl_curl_ws_send(WS, x),
                 pl_curl_ws_recv(WS, 2000, text(x)) )),
       fail
     ; true )).
