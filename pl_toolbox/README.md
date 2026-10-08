Toolbox for Prolog
==================

Small helpers for SWI-Prolog and GNU Prolog: maths and vector arithmetic,
string and stream handling, a JSON parser/encoder, and (SWI-Prolog only)
`pl_temporary_file/3`, which safely creates a temporary file.


QUICKSTART
----------

```prolog
?- use_module(sbcl(toolbox)).
?- from_json('{"a": [1, 2.5, "x"]}', J), to_json(J, A).
J = json([a=[1, 2.5, x]]),
A = '{"a":[1,2.5,"x"]}'.
?- vadd([1,2,3], [4,5,6], V).
V = [5, 7, 9].
```

JSON objects are `json([Name=Value, ...])`, arrays are lists, strings are
atoms, and `true`, `false`, `null` are atoms.

Each group of predicates is listed by an `info_*` predicate:

```
 ?- toolbox:info_math.
Prolog Toolbox, Mathematical Functors
pi(X)                       X is 3.14159....
e(X)                        X is 2.71828....
det([[X1,X2][Y1,Y2]],D)     D is the determinant
rad2grad(R,G)               G=R*180/PI
grad2rad(G,R)               R=G*PI/180
```

```
 ?- toolbox:info_vector.
Prolog Toolbox, Vector Arithmetic
vrand(N,V)                  vector containing N random numbers
vzero(N,V)                  vector containing N dimensions, all zero
vnorm(V,Vnorm)              Vnorm = V / |V|
vval(V,Value)               Value = |V|
vsum(V,Value)               Value = Sigma(V)
vadd(V1,V2,Vres)            Vres = V1 + V2
vsub(V1,V2,Vres)            Vres = V2 - V1
vmul(Konst,V,Vres)          Vres = Konst * V
vdiv(Konst,V,Vres)          Vres = V / Konst
vdist(V1,V2,Distance)       Distance = |V1 - V2|
vscal(V1,V2,Product)        Product = V1 * V2
vprod(V1,V2,Vres)           Vres = V1 x V2
vmix(V1,V2,V3,Res)          Res = (V1 x V2) * V3
```

```
 ?- toolbox:info_string.
Prolog Toolbox, String handling
removesublist(ListIn,SubL,ListOut) Removes all occurencies of SubL in ListIn
sub_string(Str,From,To,Res)        extracts substring From position To from Str
list2string(List,String)           makes a string from a list separated by " "
list2string(List,Sep,String)       makes a string from a list separated by Sep
string2list(String,Lres)           makes a list of tokens from string by " "
string2list(String,Sep,Lres)       makes a list of tokens from string by Sep
split(Str,Char,Res1,Res2)          splits at first Char into Res1 and rest to Res2
remove_leading(Str,Char,Res)       removes leading Chars from Str, always true
remove_trailing(Str,Char,Res)      removes trailing Chars from Str, always true
skip(Str,Num,Res)                  skips Num chars in Str and returns as Res
align_left(Str,Width,Res)          aligns Str to the left, appends spaces
align_right(Str,Width,Res)         aligns Str to the right, fills with spaces
lower_case(Str,LowerS)             changes Str to lowercase
upper_case(Str,UpperS)             changes Str to uppercase
```

```
 ?- toolbox:info_stream.
Prolog Toolbox, Stream handling
read_txtline(String)             reads a line from the current text Stream into String
read_txtline(Stream,String)      reads a line from a text Stream into String
read_binline(Stream,String)      reads a line from a binary Stream into String
read_txtuntil(Sep,String)        reads a line from the current text Stream into String until Sep occurs
read_txtuntil(Stream,Sep,String) reads a line from a text Stream into String until Sep occurs
read_binuntil(Stream,Sep,String) reads a line from a text Stream into String until Sep occurs
write_txtline(String)            writes a string to the current text stream.
write_txtline(Stream,String)     writes a string to the text stream.
write_binline(Stream,String)     writes a string to the binary stream.
read_n_bytes(Stream,N,Res)       reads up to N bytes from the binary Stream.
read_n_chars(Stream,N,Res)       reads up to N chars from the text Stream.
read_int_[BE|LE](Stream,Int)     reads a 32 bit integer from the binary Stream.
read_short_[BE|LE](Stream,Int)   reads a 16 bit integer from the binary Stream.
read_double_[BE|LE](Stream,Res)  reads a double in ieee extended format from the binary Stream.
```

```
 ?- toolbox:info_json.
Prolog Toolbox, JSON processing
from_json(Input,Json)             decodes Input (atom/string/codes) into a Json term
to_json(Json,Atom)                encodes a Json term into an atom
json_print(Json)                  prints the Json term to the current stream
```

`removesublist/3`, `list2string/2,3` and the `read_*_LE/BE` helpers not in
the export list are called as `toolbox:Name(...)`.

`toolbox:pl_temporary_file(+Dir, +Prefix, -File)` creates a new empty file
`Dir/<Prefix>XXXXXX` (at most 5 characters of Prefix are used) with mode 0600
and returns its path; it fails if Dir is not a directory.


HOW TO COMPILE
--------------

From the repository root `./make.sh pl_toolbox`, or in this directory
`make` (platform settings are in `../mk/<uname -s>.def`). This builds

* `pltoolbox-<platform>`: the SWI-Prolog foreign library,
* `src/toolbox.qlf`: the precompiled SWI-Prolog module,
* `libpltoolbox-<platform>.a`: the GNU Prolog library.

`make check` runs the JSON tests with GNU Prolog (and SWI-Prolog).


INSTALLATION (SWI-Prolog)
-------------------------

Copy `pltoolbox-<platform>` to `~/lib/sbcl/pltoolbox` and
`src/toolbox.qlf` to `~/lib/sbcl/toolbox.qlf`, and add the search path to
your init file (`~/.config/swi-prolog/init.pl`):

```prolog
:- assertz(file_search_path(sbcl, '/home/<your username>/lib/sbcl')).
```


GNU PROLOG
----------

Link the library into your program:

```sh
gplc -o myprog myprog.pl libpltoolbox-$(uname -s).a
```

or build a top level with all predicates: `make top`.


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
