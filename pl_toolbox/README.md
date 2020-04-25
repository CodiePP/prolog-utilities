Toolbox for Prolog
==================

Copyright (C) 1999-2020  Alexander Diemand


EXAMPLES
--------

use_module(sbcl(toolbox)).	% loads module

in ~/.swiplrc add to the search path:

> :- assertz(file_search_path(sbcl,'/home/<your username>/lib/sbcl')).


HOW TO COMPILE (SWI-Prolog)
---------------------------

You might want to adapt the `.def` file for your platform.

in this directory:

```
make
```
copy the resulting file `pltoolbox-<platform>` to `~/lib/sbcl/pltoolbox`.

in the 'src' directory:

```
consult('toolbox').
qcompile('toolbox').
```
copy the resulting file `toolbox.qlf` to `~/lib/sbcl/toolbox.qlf`.


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
