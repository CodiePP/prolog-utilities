#!/bin/sh
# Builds the modules given as arguments, or all of them:
#
#   ./make.sh                      all modules
#   ./make.sh pl_toolbox pl_curl   only these
#
# Stops at the first module that fails. pl_postgresql is configured first
# (autoreconf -fi, ./configure) unless that was done already.
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
    case "$m" in
        pl_postgresql)
            (
                cd pl_postgresql
                [ -x configure ] || autoreconf -fi
                [ -f Makefile ] || ./configure
                make
            )
            ;;
        *)
            make -C "$m"
            ;;
    esac
done
