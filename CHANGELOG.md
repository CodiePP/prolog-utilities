Changelog
=========

All notable changes. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).


0.2.0 - 2026-10-08
------------------

### Incompatible changes

* Exceptions from all modules are now `error(Formal, context(Predicate, _))`
  with the same terms in SWI-Prolog and GNU Prolog:
  `curl_error(Message)` (was `error(Message, 'pl_curl_get/5')`, and a plain
  string in GNU Prolog), `pgsql_error(Message)`, `syntax_error(Message)` for
  an invalid regular expression and `regex_error(Message)`; ISO formals for
  bad arguments. SWI-Prolog prints them as readable messages.
* pl_regexp: `Matches` is always `[Whole, Group1, ..., GroupN]`; a pattern
  without groups now gives `[Whole]` instead of `[]` (SWI-Prolog), and GNU
  Prolog no longer drops the last group. `Matches` may be bound.
  `pl_regexp/3` is exported, so `regexp:` is no longer needed.
* pl_cgi: `@name@` in templates is HTML-escaped; use `@!name@` for the old,
  unescaped output. A GET request no longer reads stdin. Input over 1 MiB
  raises `resource_error(cgi_input_length(Max))`.
* pl_curl: requests time out after 300 s (connect: 30 s) and bodies are
  limited to 64 MiB unless set with `timeout/1`, `connect_timeout/1`,
  `max_body/1`. Only http(s) URLs are fetched. Option arguments of the
  wrong type raise a `type_error` instead of being misread.
* pl_postgresql: connection handles are blobs instead of integers.
  `pl_pgsql_query/2` raises an error for failed statements (it reported
  success before). Text values starting with `NULL` are no longer returned as
  `[]`; only SQL NULL is.
* Build: the per-module `Linux.def`/`Darwin.def` files moved to `mk/`;
  pl_postgresql is prepared with `autoreconf -fi` (the vendored `config/`
  scripts are gone). Requires SWI-Prolog >= 8.0, GNU Prolog >= 1.4.0,
  libcurl >= 7.58.0, autoconf >= 2.70.

### Added

* pl_postgresql: parameterised queries `pl_pgsql_exec/3` and
  `pl_pgsql_query_all/4`.
* pl_curl: options `max_body(Bytes)` and `body_as(atom|string|codes)`;
  connections are kept alive and reused within a thread.
* pl_cgi: `cgi_env(plMaxInput, Bytes)`; `write_html_escaped/1` for template
  goals.
* `make asan`; `./make.sh` takes module names; clear messages when SWI-Prolog
  headers or `gplc` are missing; pinned `shell.nix`.
* CI (Forgejo Actions) with unit and integration tests for all modules.
* SECURITY.md, this changelog, quickstarts in the READMEs.

### Fixed

* Memory safety in the C bridges: stack overflow on PostgreSQL connect
  errors, use after free of PostgreSQL connections, wrong pointer type in the
  temporary file helper, uninitialised option values in pl_curl, leaked and
  out-of-range regex matches in pl_regexp.
* `pl_temporary_file/3` uses `mkstemp` (no symlink race).
* pl_cgi: header values cannot inject headers (CR/LF removed); invalid
  `%` escapes are kept as is; cookies work with GNU Prolog.
* pl_curl: CR/LF in headers and credentials are rejected; long bearer tokens
  and headers are no longer truncated; bodies keep NUL bytes.
* JSON: the parser was exponential in the nesting depth; parsing and encoding
  are now linear (about 3x faster on 1 MB documents).
* pl_toolbox: `list2string/2,3` raised an instantiation error (broken since
  the GNU Prolog remake); values are now written as by `write/1` on both
  systems.
* pl_toolbox: `info_math` showed swapped formulas for `rad2grad/grad2rad`
  and a wrong value of pi.


0.1.0 - 2026-10-06
------------------

First tagged version: pl_toolbox (with JSON), pl_regexp, pl_cgi, pl_curl
(libcurl GET for SWI-Prolog and GNU Prolog), pl_postgresql.
