Regular expressions in Prolog
=============================


THE PREDICATE
-------------

```
pl_regexp(+String, +Pattern, -Matches)
```

Matches `String` against the POSIX extended regular expression `Pattern`
(both atoms, strings or code lists; GNU Prolog: atoms or code lists).

* On success, `Matches` is `[Whole, Group1, ..., GroupN]`: the part of
  `String` that matched, followed by one atom per parenthesised group of the
  pattern, in order. A group that did not take part in the match (e.g.
  `(b)?`) gives `''`. A pattern without groups gives `[Whole]`.
* Fails if `String` does not match.
* Raises `error(syntax_error(Message), context(pl_regexp/3, _))` if
  `Pattern` is invalid, and `instantiation_error` if `String` or `Pattern`
  is unbound.

Both the SWI-Prolog and the GNU Prolog bridge follow this contract. (Before
2026-10, the SWI-Prolog bridge returned `[]` for patterns without groups and
the GNU Prolog bridge left out the last group.)


EXAMPLES
--------

load module:
```
use_module(sbcl(regexp)).
```

1) something that works:

```
| ?- pl_regexp("1999/12/11", "([0-9]+)/(.*)/(.*)", X).

X = ['1999/12/11', '1999', '12', '11']

Yes
```

2) when it fails:

```
| ?- pl_regexp("abcdefg","GNU", X).

no
```


SECURITY: TRUSTED PATTERNS ONLY
-------------------------------

`pl_regexp/3` hands the pattern to the C library's POSIX `regcomp`/`regexec`
as is, and compiles it again on every call. There is no time or size limit:
some patterns (nested repetition such as `(a*)*b`, large bounded repeats such
as `(a{1,255}){1,255}`, back-references) can make matching take a very long
time or use a lot of memory, depending on the C library. A program that lets
users supply patterns can therefore be blocked (denial of service).

* Only use patterns that are part of your program (or otherwise trusted).
* Never build a pattern from request parameters, cookies or other user input;
  if you must match user input against a user-chosen text, use a plain
  substring search (e.g. `sub_atom/5`) instead.
* The subject string may come from users, but limit its length.


HOW TO COMPILE
--------------

Just type `make` to compile and link the library as well as the test program.

You can use the pl_regexp/3 predicate in your code if you load the library into your code:

```
use_module(sbcl(regexp)).
```

The regex functions we use is implemented in the libc (at least on Linux).
Check that the header file <regex.h> is found by the compiler in its standard place (usually: /usr/include).


GNU PROLOG top
--------------

```
gplc -o test-gp --new-top-level src/top-regexp.pl  libplregexp-Linux.a
```


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
