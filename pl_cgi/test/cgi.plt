% Unit tests for the CGI module: request parsing (GET/POST, percent-decoding,
% input limit) and output (escaping of @var@, header sanitising).

:- use_module(library(plunit)).
:- use_module(sbcl(cgi)).

reset :-
    retractall(cgi:cgi_env(_, _)),
    retractall(cgi:cgi_in(_, _)),
    retractall(cgi:cgi_cookies(_, _)),
    forall(member(V, ['REQUEST_METHOD', 'QUERY_STRING', 'CONTENT_LENGTH', 'HTTP_COOKIE']),
           unsetenv(V)).

% get(+QueryString): runs init_cgi for a GET request
get(Query) :-
    reset,
    setenv('REQUEST_METHOD', 'GET'),
    setenv('QUERY_STRING', Query),
    cgi:init_cgi.

% post(+Body, +ContentLength): runs init_cgi for a POST request with Body on stdin
post(Body, Len) :-
    reset,
    setenv('REQUEST_METHOD', 'POST'),
    ( Len == none -> true ; setenv('CONTENT_LENGTH', Len) ),
    setup_call_cleanup(open_string(Body, In),
                       with_input(In, cgi:init_cgi),
                       close(In)).

with_input(In, Goal) :-
    current_input(Old),
    setup_call_cleanup(set_input(In), Goal, set_input(Old)).

% render(+Template, -Output): output of generate_html_output/3 for a template text
render(Template, Output) :-
    tmp_file_stream(text, File, S),
    write(S, Template),
    close(S),
    call_cleanup(with_output_to(string(Output),
                                cgi:generate_html_output([cgi_in], File, [no_HTML_header])),
                 delete_file(File)).

header_output(Output) :-
    with_output_to(string(Output), cgi:output_html_header).

:- begin_tests(cgi_input).

test(get_params, [cleanup(reset)]) :-
    get('name=test&age=42'),
    cgi:cgi_in(name, test),
    cgi:cgi_in(age, '42').

test(percent_and_plus_decoding, [cleanup(reset)]) :-
    get('q=a+b%26c%3dd'),
    cgi:cgi_in(q, 'a b&c=d').

test(invalid_percent_escape_kept, [cleanup(reset)]) :-
    get('q=100%zz%4'),
    cgi:cgi_in(q, '100%zz%4').

test(filter_is_deterministic, [true(Ls == [[0'A]])]) :-
    findall(L, cgi:filter(`%41`, L), Ls).

test(post_body, [cleanup(reset)]) :-
    post("name=x&v=y%20z&ignored", '14'),
    findall(N-V, cgi:cgi_in(N, V), Ps),
    msort(Ps, [name-x, v-'y z']).

test(post_without_content_length, [cleanup(reset)]) :-
    post("a=1", none),
    cgi:cgi_in(a, '1').

test(get_too_long, [throws(error(resource_error(cgi_input_length(10)), _)), cleanup(reset)]) :-
    reset,
    assertz(cgi:cgi_env(plMaxInput, 10)),
    setenv('REQUEST_METHOD', 'GET'),
    setenv('QUERY_STRING', 'a=0123456789'),
    cgi:init_cgi.

test(post_content_length_too_long, [throws(error(resource_error(cgi_input_length(_)), _)),
                                    cleanup(reset)]) :-
    post("a=1", '2000000').

test(post_without_length_too_long, [throws(error(resource_error(cgi_input_length(5)), _)),
                                    cleanup(reset)]) :-
    reset,
    assertz(cgi:cgi_env(plMaxInput, 5)),
    setenv('REQUEST_METHOD', 'POST'),
    setup_call_cleanup(open_string("a=123456", In), with_input(In, cgi:init_cgi), close(In)).

:- end_tests(cgi_input).

:- begin_tests(cgi_output).

test(var_is_escaped, [cleanup(reset)]) :-
    get('name=%3Cscript%3Ealert(%27x%27)%3C%2Fscript%3E%26%22'),
    render("<p>@name@</p>", Out),
    Out == "<p>&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;&amp;&quot;</p>".

test(raw_var_not_escaped, [cleanup(reset)]) :-
    get('html=%3Cb%3E'),
    render("@!html@", Out),
    Out == "<b>".

test(unknown_tag_copied, [cleanup(reset)]) :-
    get('a=1'),
    render("mail@example.org", Out),
    Out == "mailexample.org".

test(header_crlf_stripped, [cleanup(reset)]) :-
    reset,
    assertz(cgi:cgi_env(plLocation, '/x\r\nSet-Cookie: evil=1')),
    header_output(Out),
    split_string(Out, "\n", "", Lines),
    \+ ( member(L, Lines), sub_string(L, 0, _, _, "Set-Cookie") ),
    once(sub_string(Out, _, _, _, "Location: /xSet-Cookie: evil=1\n")).

:- end_tests(cgi_output).
