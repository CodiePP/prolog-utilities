
SWI-Prolog example
==================

compilation
-----------

swipl -q -f ~/.swiplrc -t run -o swi-test.cgi -c swi-test.pl

GET request
-----------

REQUEST_METHOD=GET QUERY_STRING='name=test&age=42' ./swi-test.cgi


GNU Prolog example
==================

compilation
-----------

gplc --no-top-level -o gp-test.cgi gp-test.pl ../libplcgi-Linux.a ../../pl_regexp/libplregexp-Linux.a ../../pl_toolbox/libpltoolbox-Linux.a

GET request
-----------

REQUEST_METHOD=GET QUERY_STRING='name=test&age=42' ./gp-test.cgi

