#!/bin/sh
# Unit tests: runs every pl_*/test/*.plt (plunit) that does not need external
# services. Integration tests are named it_*.plt and are run by the ci/it-*.sh
# scripts. Needs a finished ci/build.sh.
set -eu
cd "$(dirname "$0")/.."
. ci/env.sh

files=$(find pl_* -path '*/test/*.plt' ! -name 'it_*' | sort)
if [ -z "$files" ]; then
    echo "no unit tests found (pl_*/test/*.plt)" >&2
    exit 1
fi

failed=""
for f in $files; do
    echo "::: $f"
    $SWIPL -q -g "load_files('$f', [silent(true)]), run_tests" -t halt || failed="$failed $f"
done

if [ -n "$failed" ]; then
    echo "FAILED:$failed" >&2
    exit 1
fi
echo "::: all unit tests passed"
