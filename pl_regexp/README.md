Regular expressions in Prolog
=============================

Copyright (C) 1999-2020  Alexander Diemand


EXAMPLES
--------
1) something that works:

```
| ?- regexp:pl_regexp("1999/12/11", "([0-9]+)/(.*)/(.*)", X).

X = ['1999/12/11', '1999', '12', '11']

Yes
```

2) when it fails:

```
| ?- regexp:pl_regexp("abcdefg","GNU", X).

no
```


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
gplc -o test-gp --new-top-level gp-regexp.pl  libplregexp-Linux.a
```


LICENSE
-------

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
