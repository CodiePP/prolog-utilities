#!/bin/sh

# load SWI-Prolog environment
eval $(swipl --dump-runtime-variables)

export PLBASE

make
