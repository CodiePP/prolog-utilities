% extends SWI-Prolog's search path:
:- assertz(file_search_path(sbcl,'/Users/axeld/lib/sbcl')).

run :-
	use_module(sbcl(cgi)),
	init_cgi,
	asserta(cgi:cgi_env(plPragma,'Cacheable')),
	template(Tf),
	generate_html_output(['cgi_var','cgi_in'],Tf),
	halt.

template('test101.0').

