
compilation
-----------

swipl -q -f ~/.swiplrc -t run -o test.cgi -c test.pl

GET request
-----------

REQUEST_METHOD=GET QUERY_STRING='name=test&age=42' ./test.cgi

