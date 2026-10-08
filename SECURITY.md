Security
========

Reporting a vulnerability
-------------------------

Please do not open a public issue for security problems. Report them
privately through GitHub's "Report a vulnerability" button on the
repository's Security tab
(<https://github.com/CodiePP/prolog-utilities/security>). You will get an
answer within reasonable time. Fixes are made on `main`; there are no maintained
release branches.


What the modules protect against
--------------------------------

These libraries are meant to be used with untrusted *data*, not with
untrusted *code or configuration*. In particular:

* **pl_cgi**: `@name@` in templates is HTML-escaped; `@!name@` and the output
  of `{Goal}` are not (use `write_html_escaped/1`). CR/LF are removed from
  response header values. Request input is limited to 1 MiB by default.
  Templates are program code: never choose a template file from request data.
* **pl_curl**: only `http://` and `https://` (also on redirects), at most 10
  redirects, default timeouts and a 64 MiB body limit, CR/LF rejected in
  headers and credentials, TLS verification on by default (`ssl_verify(false)`
  turns it off; do not use that in production).
* **pl_postgresql**: use `pl_pgsql_exec/3` and `pl_pgsql_query_all/4` with
  parameters for any value that comes from users; never build SQL text by
  concatenation. Connection handles cannot be forged or used after
  disconnect.
* **pl_regexp**: patterns must be trusted; there is no time limit on
  matching (see its README).
* **pl_toolbox**: `from_json/2` parses in linear time, but has no limit on
  input size or nesting depth; limit the input size yourself.
  `pl_temporary_file/3` creates files exclusively with mode 0600.

The C code is built with warnings, `_FORTIFY_SOURCE=2`, stack protection and
(on Linux) full RELRO; `make asan` builds with AddressSanitizer and
UndefinedBehaviorSanitizer for testing.
