libcurl HTTP interface for Prolog
==================================

Foreign-function bridge to [libcurl](https://curl.se/libcurl/) for both
GNU Prolog and SWI-Prolog. First release covers HTTP GET; the request
term is designed to extend to other methods later.


THE PREDICATE
--------------

```
pl_curl_get(+URL, +Options, -Status, -Headers, -Body)
```

* `URL` — atom/string, the base URL without a query string.
* `Options` — a list of option terms (any subset, any order):

  | term                        | meaning                                              |
  |------------------------------|-------------------------------------------------------|
  | `param(Name, Value)`         | query parameter; URL-encoded and appended to `URL`; repeatable |
  | `header(Name, Value)`        | extra request header; repeatable                     |
  | `basic_auth(User, Pass)`     | HTTP Basic authentication credentials                 |
  | `bearer_auth(Token)`         | sends `Authorization: Bearer <Token>`                 |
  | `timeout(Seconds)`           | total request timeout                                 |
  | `connect_timeout(Seconds)`   | connection-phase timeout                              |
  | `follow_redirect(Bool)`      | follow `Location` redirects, default `true`           |
  | `ssl_verify(Bool)`           | verify the TLS certificate/host, default `true`       |
  | `user_agent(Atom)`           | custom `User-Agent` header                            |

* `Status` — unifies with the HTTP status code (integer).
* `Headers` — unifies with a list of `Name-Value` pairs (response headers, in order received).
* `Body` — unifies with the response body.

A transport-level failure (DNS, connection refused, TLS handshake, timeout, ...)
throws a Prolog exception. An HTTP error status (404, 500, ...) is *not* an
exception — it is returned in `Status` like any other response, so the caller
decides how to handle it.

EXAMPLES
--------

```prolog
?- pl_curl_get('https://httpbin.org/get',
               [ param(hello, world),
                 header('X-Test', '1'),
                 timeout(10)
               ],
               Status, Headers, Body).

Status = 200,
Headers = ['Content-Type'-'application/json', ...],
Body = '{"args": {"hello": "world"}, ...}'.
```

```prolog
?- pl_curl_get('https://api.example.com/me',
               [ bearer_auth('secret-token'),
                 ssl_verify(true)
               ],
               Status, _, Body).
```

```prolog
?- pl_curl_get('https://api.example.com/private',
               [ basic_auth(alice, hunter2) ],
               Status, _, Body).
```


HOW TO COMPILE
---------------

Requires the libcurl development headers (`curl/curl.h`) and library to be
available to the compiler/linker — usually already the case on macOS and on
Linux with `libcurl4-openssl-dev` (or equivalent) installed.

Just type `make` to compile and link the SWI-Prolog shared library, the
GNU Prolog static library, and precompile `curl.pl` to a `.qlf` file.

Load it from SWI-Prolog with:

```prolog
use_module(sbcl(curl)).
```


GNU PROLOG top
---------------

```
gplc -o test-gp --new-top-level src/top-curl.pl libplcurl-$(uname -s).a -L -lcurl
```

or simply `make top`.


DESIGN NOTES
------------

The libcurl calls themselves live in `src/curl_core.c` / `src/curl_core.h`,
a small C library with no dependency on either Prolog's C interface. Both
bridges (`src/gp-curl-c.c` for GNU Prolog, `src/swi-curl.c` for SWI-Prolog)
only translate between their own term representation and this shared core,
so the two Prolog systems stay behaviourally identical and any future
addition (POST, PUT, DELETE, multipart bodies, ...) only needs to be taught
to `curl_core.c` once.


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
