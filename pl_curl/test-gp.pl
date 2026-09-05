/* gplc -o test-gp --new-top-level test-gp.pl libplcurl-$(uname -s).a -L -lcurl */

:- include('../pl_toolbox/src/json.pl').

testcurl :-
  pl_curl_get('https://httpbin.org/get',
              [ param(hello, world),
                header('X-Test', '1'),
                header('Accept', 'application/json'),
                timeout(10)
              ],
              Status, Headers, Body),
  format("status: ~p~n", [Status]),
  format("headers: ~p~n", [Headers]),
  from_json(Body, Json),
  write('response: '), json_print(Json), nl.
