Prolog CGI programming
======================

Write CGI programs (scripts run by a web server for each request) in
SWI-Prolog or GNU Prolog: `init_cgi` parses the request parameters and
cookies, `generate_html_output/1,2,3` writes the response headers and fills
an HTML template. Needs `pl_regexp` and `pl_toolbox`.

Quickstart (SWI-Prolog, see `test/` for a complete example):

```prolog
:- use_module(sbcl(cgi)).

run :-
    init_cgi,                                  % parse QUERY_STRING / POST body
    generate_html_output('hello.html'),        % headers + template, uses cgi_in/2
    halt.
```

with `hello.html` containing `<h1>Hello @name@</h1>`. Then
`REQUEST_METHOD=GET QUERY_STRING='name=World' swipl -g run -t halt hello.pl`
prints the page with `Hello World`.

After `init_cgi` you can set the variable cgi_env(plContentType,'text/html'), 
which controls what content type for the document is being used, to something
different.


Content type
------------
per default the output is thought to be HTML:

`cgi_env('plContentType', 'text/html').`

though this can be overridden.

Variables
---------
variables are parsed into predicates:

`cgi_in(<name>,<content>).`

The request parameters are read from `QUERY_STRING` (method GET) or from
stdin (other methods, at most `CONTENT_LENGTH` bytes). Input longer than
1 MiB makes `init_cgi` throw `error(resource_error(cgi_input_length(Max)),_)`;
assert `cgi_env(plMaxInput, Bytes)` before `init_cgi` to change the limit.

Cookies
-------
are available in the predicate:

`cgi_cookies(<name>,<content>).`

Templates
---------
`generate_html_output(Predlist, File)` copies the template File to the
output, replacing

* `@name@` with the value `V` of the first `P(name, V)` fact for a predicate
  `P` in Predlist (default `[cgi_in]`). The value is HTML-escaped
  (`<`, `>`, `&`, `"`, `'`), so request parameters cannot inject markup or
  scripts into the page.
* `@!name@` likewise, but **without** escaping. Only use it for values the
  application controls, never for request parameters or cookies.
* `{Goal}` with whatever `Goal` writes; `Goal` is read as Prolog term up
  to the next `}` and called once (a failing goal writes nothing more).
  The goal's output is **not** escaped: use `write_html_escaped/1` for
  anything that comes from the request, e.g.
  `{cgi_in(A,B),write(A),write(': '),write_html_escaped(B),nl,fail.}`.
* `\{` with a literal `{` (other `\` are copied unchanged).

A literal `@` (e.g. in an e-mail address) starts a tag and is dropped, so write
addresses in templates as `{write('me@example.org')}` or `&#64;`.

`generate_html_output(Predlist, File, [no_HTML_header])` writes only the
template, without response headers. Templates are trusted program code (they
can call any goal); never use a template path that comes from the request.

Headers
-------
`cgi_env/2` facts for `plContentType`, `plStatus`, `plPragma`,
`plCacheControl`, `plLocation` and `plModified` are written as response
headers. CR and LF are removed from their values, so a value that contains
user input cannot add further headers.


LICENSE
-------

Copyright (C) 1999-2026  Alexander Diemand

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

