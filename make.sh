#!/bin/sh
# Builds the modules given as arguments, or all of them:
#
#   ./make.sh                      all modules
#   ./make.sh pl_toolbox pl_curl   only these
#
# Stops at the first module that fails.
set -eu
cd "$(dirname "$0")"

# load SWI-Prolog environment
eval "$(swipl --dump-runtime-variables)"

export PLBASE
export PLLIBDIR
export PLLIB

if [ $# -eq 0 ]; then
    set -- pl_toolbox pl_regexp pl_cgi pl_curl pl_postgresql
fi

for m in "$@"; do
    echo "::: building $m"
    make -C "$m"
done
