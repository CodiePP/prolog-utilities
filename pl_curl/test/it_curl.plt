% Integration tests for pl_curl_get/5 against pl_curl/test/http_fixture.pl.
% Run with ci/it-curl.sh (starts the fixture first). Env: FIXTURE_PORT (18080).
%
% Note: option values must be atoms/strings; pl_curl_get/5 does not check the
% type of its option arguments (param(y, 2) reads uninitialised memory), so
% there is deliberately no test for that.
%
% Tests marked fixme document known defects (see the repo review); a fixme
% test that starts to pass is reported as fixed, a failing one does not fail
% the run. Drop the fixme option once the defect is resolved.

:- use_module(library(plunit)).
:- use_module(sbcl(toolbox)).
:- use_module(sbcl(curl)).

base(Path, URL) :-
    ( getenv('FIXTURE_PORT', P) -> true ; P = '18080' ),
    atomic_list_concat(['http://127.0.0.1:', P, Path], URL).

% get(+Path, +Options, -Status, -Headers, -Body)
get(Path, Opts, Status, Headers, Body) :-
    base(Path, URL),
    pl_curl_get(URL, Opts, Status, Headers, Body).

% echo(+Path, +Options, -Args, -Headers): decoded JSON of /get
echo(Path, Opts, Args, Headers) :-
    get(Path, Opts, 200, _, Body),
    toolbox:from_json(Body, json(Top)),
    memberchk(args=json(Args), Top),
    memberchk(headers=json(Headers), Top).

header_value(Name, Headers, Value) :-
    member(N-Value, Headers),
    downcase_atom(N, Name), !.

:- begin_tests(curl_it).

test(status_headers_body) :-
    get('/get', [], Status, Headers, Body),
    Status == 200,
    header_value('content-type', Headers, CT),
    once(sub_atom(CT, _, _, _, 'application/json')),
    once(sub_atom(Body, _, _, _, '"args"')).

test(query_params_are_url_encoded) :-
    echo('/get', [param(hello, world), param(q, 'a b&c=d')], Args, _),
    memberchk(hello=world, Args),
    memberchk(q='a b&c=d', Args).

test(params_appended_to_existing_query) :-
    echo('/get?x=1', [param(y, '2')], Args, _),
    memberchk(x='1', Args),
    memberchk(y='2', Args).

test(custom_header) :-
    echo('/get', [header('X-Test', '1')], _, Headers),
    memberchk(x_test='1', Headers).

test(user_agent) :-
    echo('/get', [user_agent('plu-it/1.0')], _, Headers),
    memberchk(user_agent='plu-it/1.0', Headers).

test(bearer_auth) :-
    echo('/get', [bearer_auth(tok123)], _, Headers),
    memberchk(authorization='Bearer tok123', Headers).

test(basic_auth) :-
    echo('/get', [basic_auth(alice, secret)], _, Headers),
    memberchk(authorization='Basic YWxpY2U6c2VjcmV0', Headers).

test(http_error_status_is_not_an_exception) :-
    get('/status/404', [], Status, _, _),
    Status == 404.

test(http_server_error_status) :-
    get('/status/500', [], Status, _, _),
    Status == 500.

test(redirect_followed_by_default) :-
    get('/redirect', [], Status, _, Body),
    Status == 200,
    once(sub_atom(Body, _, _, _, '"args"')).

test(redirect_not_followed) :-
    get('/redirect', [follow_redirect(false)], Status, Headers, _),
    Status == 303,
    header_value(location, Headers, Loc),
    Loc == '/get'.

test(timeout_raises, [throws(error(Msg, 'pl_curl_get/5'))]) :-
    get('/slow', [timeout(1)], _, _, _),
    atom(Msg).

test(connection_refused_raises, [throws(error(_, 'pl_curl_get/5'))]) :-
    pl_curl_get('http://127.0.0.1:1/', [connect_timeout(2)], _, _, _).

test(bad_url_raises, [throws(error(_, 'pl_curl_get/5'))]) :-
    pl_curl_get('http://no-such-host.invalid/', [connect_timeout(2)], _, _, _).

% --- known defects ----------------------------------------------------

test(utf8_body_decoded, [fixme('body is returned as a Latin-1 atom; should be UTF-8')]) :-
    get('/utf8', [], 200, _, Body),
    atom_codes(Expected, [0'G, 0'r, 252, 223, 0'e, 0' , 128512]),
    Body == Expected.

test(file_scheme_refused, [fixme('SEC-6: only http(s) should be accepted'),
                           throws(error(_, 'pl_curl_get/5'))]) :-
    tmp_file(plu, F),
    setup_call_cleanup(( open(F, write, S), write(S, secret), close(S) ),
                       ( atom_concat('file://', F, URL),
                         pl_curl_get(URL, [], _, _, _) ),
                       delete_file(F)).

:- end_tests(curl_it).
