
SWI-Prolog example
==================

compilation
-----------

% swipl -q -f ~/.config/swi-prolog/init.pl -t run -o swi-test.cgi -c swi-test.pl


GET request
-----------

%REQUEST_METHOD=GET QUERY_STRING='name=test&age=42' ./swi-test.cgi
REQUEST_METHOD=GET QUERY_STRING='name=test&age=42' swipl -t run swi-test.pl

GNU Prolog example
==================

compilation
-----------

gplc --no-top-level -o gp-test.cgi gp-test.pl ../libplcgi-$(uname -s).a ../../pl_regexp/libplregexp-$(uname -s).a ../../pl_toolbox/libpltoolbox-$(uname -s).a

GET request
-----------

REQUEST_METHOD=GET QUERY_STRING='name=test&age=42' ./gp-test.cgi

