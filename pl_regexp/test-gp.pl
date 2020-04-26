/* gplc -o test-gp --new-top-level test-gp.pl libplregexp-Linux.a */

testre :-
  pl_regexp("1999/12/11", "([0-9]+)/(.*)/(.*)", R),
  format("~p", [R]).

