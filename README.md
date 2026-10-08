
Prolog utilities
================

Libraries that give SWI-Prolog and GNU Prolog programs access to things the
base systems lack or handle differently: HTTP requests (libcurl), PostgreSQL,
POSIX regular expressions, CGI scripting with HTML templates, and a toolbox
with JSON, string, stream and vector helpers. Each module is a small C
bridge and/or Prolog code, built for both Prolog systems where possible.

| module | what it does | SWI-Prolog | GNU Prolog | needs |
|---|---|---|---|---|
| [pl_toolbox](pl_toolbox) | JSON parser/encoder, strings, streams, maths, vectors, safe temporary files | yes | yes (no temp files) | |
| [pl_regexp](pl_regexp) | POSIX extended regular expressions: `pl_regexp/3` | yes | yes | libc `<regex.h>` |
| [pl_cgi](pl_cgi) | CGI requests, cookies, HTML templates with escaping | yes | yes | pl_toolbox, pl_regexp |
| [pl_curl](pl_curl) | HTTP(S) GET with parameters, headers, auth, limits: `pl_curl_get/5` | yes | yes | libcurl |
| [pl_postgresql](pl_postgresql) | PostgreSQL queries, parameterised statements | yes | no | libpq |

Supported platforms: Linux and macOS.


Quickstart
----------

```sh
nix-shell                  # or install the requirements below yourself
ci/build.sh                # builds all modules into build/stage
swipl -f ci/init.pl        # SWI-Prolog with the sbcl search path set up
```

```prolog
?- use_module(sbcl(curl)), use_module(sbcl(toolbox)).
?- pl_curl_get('https://api.example.org/search',      % some JSON API
               [param(q, prolog), timeout(10)],
               Status, _Headers, Body),
   from_json(Body, Json).

?- use_module(sbcl(regexp)).
?- pl_regexp("1999/12/11", "([0-9]+)/(.*)/(.*)", M).
M = ['1999/12/11', '1999', '12', '11'].
```

Each module's README has a quickstart and the full API.


Using the modules
-----------------

The SWI-Prolog modules find each other and their foreign libraries through
the file search path alias `sbcl`. Either use `swipl -f ci/init.pl` in this
repository (after `ci/build.sh`), or copy the foreign libraries
(`pl_*/<name>-<platform>`, renamed to `<name>`) and the `.qlf` files to a
directory and add it in your `~/.config/swi-prolog/init.pl`:

```prolog
:- assertz(file_search_path(sbcl, '/home/<you>/lib/sbcl')).
```

Then load modules with `use_module(sbcl(toolbox))`, `sbcl(regexp)`,
`sbcl(cgi)`, `sbcl(curl)`, `sbcl(pgsql)`.

With GNU Prolog, link the libraries into your program, e.g.
`gplc prog.pl pl_curl/libplcurl-$(uname -s).a -L '-lcurl -pthread'`.

Errors are raised as `error(Formal, context(Predicate, _))`, the same with
both Prolog systems: standard ISO formals (`type_error`, `instantiation_error`,
...) for bad arguments, and `curl_error(Message)`, `pgsql_error(Message)`,
`regex_error(Message)` or `syntax_error(Message)` (invalid regular
expression) for failures reported by the libraries.


Requirements
------------

| dependency | minimum | tested with | needed by |
|---|---|---|---|
| SWI-Prolog (headers + `swipl`) | 8.0 | 8.5.12 | SWI-Prolog builds of all modules |
| GNU Prolog (`gplc`) | 1.4.0 | 1.5.0 | GNU Prolog builds (`pl_toolbox`, `pl_regexp`, `pl_cgi`, `pl_curl`) |
| libcurl (headers + library) | 7.58.0 | 8.7.1 | `pl_curl` |
| libpq (PostgreSQL client) | 9.0 | 16 | `pl_postgresql` (SWI-Prolog only) |
| autoconf | 2.70 | 2.73 | `pl_postgresql` (`autoreconf -fi`) |
| pkg-config, make, C compiler | | | all |

The minimums are enforced at build time (`#error` in the C bridges, version
constraints in `pl_postgresql/configure.ac`); `pl_curl` also refuses to run
against an older libcurl at run time. libcurl 7.58.0 is the first version that
does not forward a `bearer_auth` token to another host on a redirect.

`nix-shell` (see [shell.nix](shell.nix), pinned nixpkgs) provides all of them.


Building
--------

```sh
./make.sh                       # all modules, stops at the first failure
./make.sh pl_toolbox pl_curl    # only some
make -C pl_regexp               # a single module (pl_postgresql: see its README)
```

`ci/build.sh` and `ci/test.sh` build everything into `build/stage` and run the
unit tests, as the CI does.

Compiler and linker flags live in [mk/Linux.def](mk/Linux.def) and
[mk/Darwin.def](mk/Darwin.def), the rules in [mk/common.mk](mk/common.mk),
shared by all module Makefiles. The C code is built with `-Wall -Wextra
-Wformat=2`, `_FORTIFY_SOURCE=2`, `-fstack-protector-strong` and, on Linux,
full RELRO (`-z relro -z now`).

`make asan` (in a module directory) rebuilds that module's libraries with
AddressSanitizer and UndefinedBehaviorSanitizer. `swipl` itself is not
instrumented, so the runtime must be preloaded; leak detection does not work
with `swipl` and must be off:

```sh
# Linux (gcc)
LD_PRELOAD="$(gcc -print-file-name=libasan.so) $(gcc -print-file-name=libubsan.so)" \
ASAN_OPTIONS=detect_leaks=0 swipl ...
# macOS (clang); an AddressSanitizer "failed to deallocate" message when
# swipl exits can be ignored
DYLD_INSERT_LIBRARIES="$(cc -print-file-name=libclang_rt.asan_osx_dynamic.dylib)" \
ASAN_OPTIONS=detect_leaks=0 swipl ...
```

Run `make clean all` afterwards to get the normal build back.


More
----

* [CHANGELOG.md](CHANGELOG.md): changes, including incompatible ones.
* [SECURITY.md](SECURITY.md): reporting vulnerabilities, and what each module
  protects against.


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
