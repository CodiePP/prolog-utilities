run :-
	init_cgi,
	asserta(cgi_env(plPragma,'Cacheable')),
	template(Tf),
	generate_html_output(['cgi_var','cgi_in'],Tf),
	halt.

template('test101.0').

:- initialization(run).
