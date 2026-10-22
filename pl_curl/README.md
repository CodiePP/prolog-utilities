libcurl HTTP interface for Prolog
==================================

Foreign-function bridge to [libcurl](https://curl.se/libcurl/) for both
GNU Prolog and SWI-Prolog: HTTP GET, and WebSocket clients for long-running
connections (see [WEBSOCKETS](#websockets)). The request term is designed
to extend to other HTTP methods later.


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
  | `timeout(Seconds)`           | total request timeout, default 300                    |
  | `connect_timeout(Seconds)`   | connection-phase timeout, default 30                  |
  | `max_body(Bytes)`            | maximum response body size, default 64 MiB            |
  | `body_as(Type)`              | type of `Body`: `atom` (default), `string` (SWI-Prolog only) or `codes` |
  | `follow_redirect(Bool)`      | follow `Location` redirects, default `true`           |
  | `ssl_verify(Bool)`           | verify the TLS certificate/host, default `true`       |
  | `user_agent(Atom)`           | custom `User-Agent` header                            |

* `Status` — unifies with the HTTP status code (integer).
* `Headers` — unifies with a list of `Name-Value` pairs (response headers, in order received).
* `Body` — unifies with the response body: each byte becomes one character
  (ISO Latin-1, no charset decoding). `body_as(string)` avoids putting large
  bodies into the atom table; `body_as(codes)` gives a list of byte values.
  With GNU Prolog an atom body ends at the first NUL byte, so use
  `body_as(codes)` for binary data.

A transport-level failure (DNS, connection refused, TLS handshake, timeout, ...)
throws `error(curl_error(Message), context(pl_curl_get/5, _))`, where Message
is libcurl's description of the problem. An HTTP error status (404, 500, ...) is *not* an
exception — it is returned in `Status` like any other response, so the caller
decides how to handle it.

Option arguments must be text (atom, string or code list) or, for the
timeouts and `max_body`, integers; anything else raises a `type_error`.
At most 64 `param/2` and 64 `header/2` options are accepted.


LIMITS AND SAFETY
-----------------

* Only `http://` and `https://` URLs are fetched, also when following
  redirects (no `file://`, `ftp://`, ...).
* At most 10 redirects are followed.
* Requests time out after `timeout(Seconds)` (default 300 s; connecting after
  `connect_timeout(Seconds)`, default 30 s). A value of 0 selects the default.
* A response body larger than `max_body(Bytes)` (default 64 MiB) aborts the
  request with an exception, so a hostile server cannot exhaust memory.
* Connections are kept open and reused (HTTP keep-alive): each Prolog
  thread keeps one libcurl handle, so repeated requests to the same server
  skip the TCP and TLS handshakes. The handle and its connections are
  released when the thread ends.
* Header names/values, credentials and the user agent must not contain CR or
  LF (that would allow injecting extra request headers); such a request
  raises an exception before anything is sent.

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


WEBSOCKETS
----------

```
pl_curl_ws_open(+URL, +Options, -WS)
pl_curl_ws_send(+WS, +Data)
pl_curl_ws_recv(+WS, +TimeoutMs, -Msg)
pl_curl_ws_close(+WS)
```

A WebSocket client connection: open it, send and receive messages for as
long as needed, close it. Typical use is a market-data feed: subscribe with
one `pl_curl_ws_send/2`, then loop on `pl_curl_ws_recv/3`.

* `pl_curl_ws_open/3` connects to a `ws://` or `wss://` URL and performs the
  opening handshake. `Options` (any subset, any order):

  | term                       | meaning                                                  |
  |----------------------------|----------------------------------------------------------|
  | `header(Name, Value)`      | extra handshake header; repeatable (at most 64)          |
  | `connect_timeout(Seconds)` | connection and handshake timeout, default 30            |
  | `max_message(Bytes)`       | maximum size of a received message, default 16 MiB      |
  | `text_as(Type)`            | type of received text: `codes` (default), `string` (SWI-Prolog only) or `atom` |
  | `ssl_verify(Bool)`         | verify the TLS certificate/host, default `true`          |
  | `user_agent(Atom)`         | custom `User-Agent` header                               |

* `pl_curl_ws_send/2` sends `Data` as one text message (an atom, string or
  code list, UTF-8 encoded), or `binary(Bytes)` with a list of byte values
  as one binary message.
* `pl_curl_ws_recv/3` waits up to `TimeoutMs` milliseconds (0: just check)
  for the next complete message and unifies `Msg` with one of:

  | `Msg`                  | meaning                                                   |
  |------------------------|-----------------------------------------------------------|
  | `text(Data)`           | a text message, of the type chosen with `text_as/1`       |
  | `binary(Bytes)`        | a binary message as a list of byte values                 |
  | `close(Code, Reason)`  | the server closed the connection (`Code` 1005: none given); the close is answered and the connection can no longer be used |
  | `timeout`              | no complete message arrived in time; the connection stays usable |

  Fragmented messages are joined; pings are answered by libcurl. A message
  still incomplete when the timeout expires is kept for the next call.
* `pl_curl_ws_close/1` sends a close frame (status 1000) and releases the
  connection.

A transport failure (connection refused, TLS, handshake refused, connection
lost, message over `max_message`, ...) throws
`error(curl_error(Message), context(Predicate, _))`; after that, and after a
`close(_, _)` message, sending or receiving throws as well, so open a new
connection (with a pause in between) to go on. Using a closed handle raises
`existence_error(curl_websocket, WS)`, passing something else as a handle
`type_error(curl_websocket, Term)`.

```prolog
?- pl_curl_ws_open('wss://ws.example.org/v2', [text_as(string)], WS),
   pl_curl_ws_send(WS, '{"method":"subscribe","params":{"channel":"ticker"}}'),
   pl_curl_ws_recv(WS, 5000, Msg),
   pl_curl_ws_close(WS).
Msg = text("{\"channel\":\"status\", ...}").
```

**Text and atoms.** The default `text_as(codes)` suits long-running
connections and parses directly with `from_json/2` (pl_toolbox). Avoid
`text_as(atom)` for a stream of messages in GNU Prolog: its atom table is a
fixed resource that is never garbage collected. SWI-Prolog decodes text
messages as UTF-8; GNU Prolog has no Unicode characters and gives one code
per byte.

**Handles.** In SWI-Prolog a connection is a blob, printed as
`<curl_websocket>(...)`, and is closed when garbage collected if it was not
closed before; still, close it explicitly. A connection must not be used by
two threads at the same time. In GNU Prolog a handle is a small integer that
is never reused for another connection, and a connection is only closed by
`pl_curl_ws_close/1` or when the process exits.

**Waiting.** In SWI-Prolog, `pl_curl_ws_recv/3` waits in steps of 200 ms
and handles signals in between, so Ctrl-C and `thread_signal/2` work during
a long timeout.

**Requirements.** WebSockets need libcurl >= 8.11.0 with WebSocket support
(the default since 8.11.0, e.g. Debian 13). With an older or a library built
without it, `pl_curl_ws_open/3` throws a `curl_error` that says so; HTTP GET
is not affected.


HOW TO COMPILE
---------------

Requires libcurl >= 7.58.0 (checked when compiling and at run time; older
versions forward a `bearer_auth` token to other hosts on redirects), and
>= 8.11.0 for WebSockets (checked at run time).
The libcurl development headers (`curl/curl.h`) and library must be
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
gplc -o test-gp --new-top-level src/top-curl.pl libplcurl-$(uname -s).a -L '-lcurl -pthread'
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

A WebSocket uses an easy handle of its own in `CURLOPT_CONNECT_ONLY` mode
(value 2: upgrade, then hand the connection over), separate from the
per-thread handle of `pl_curl_get/5`, and reads with `curl_ws_recv`,
waiting on the socket with `poll()` between reads.


LICENSE
-------

Copyright (C) 2026  Alexander Diemand

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
