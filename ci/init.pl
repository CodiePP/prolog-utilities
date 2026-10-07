% SWI-Prolog init file for CI and local test runs (swipl -f ci/init.pl ...).
%
% The libraries address each other through the file search path alias
% `sbcl`, which the README tells users to define in their own init.pl.
% Here it points at the sources and at ci/build.sh's staging directory
% (build/stage), which holds the foreign libraries.

:- multifile user:file_search_path/2.
:- dynamic   user:file_search_path/2.

:- ( getenv('PLU_ROOT', Root) -> true ; working_directory(Root, Root) ),
   forall(( member(Dir, [ 'build/stage', 'pl_toolbox/src', 'pl_regexp/src',
                          'pl_cgi/src', 'pl_curl/src', 'pl_postgresql/src' ]),
            directory_file_path(Root, Dir, Path) ),
          asserta(user:file_search_path(sbcl, Path))).
