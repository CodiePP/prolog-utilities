#!/bin/sh

# load SWI-Prolog environment
eval $(swipl --dump-runtime-variables)

export PLBASE
export PLLIBDIR
export PLLIB

make -C pl_toolbox
make -C pl_regexp
make -C pl_cgi

