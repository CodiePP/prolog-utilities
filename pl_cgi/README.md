Prolog CGI programming
======================

Copyright (C) 1999-2019  Alexander Diemand


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

Cookies
-------
are available in the predicate:

`cgi_cookies(<name>,<content>).`


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

