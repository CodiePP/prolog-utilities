#!/bin/sh
# PostgreSQL integration tests (pl_postgresql/test/it_pgsql.plt).
# Needs a finished ci/build.sh and a reachable PostgreSQL, configured through
# the libpq variables PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE.
# In CI the server is the `postgres` service container of the job; locally:
#
#   docker run --rm -d --name plu-pg -p 5432:5432 -e POSTGRES_PASSWORD=plu postgres:16
#   PGHOST=localhost PGUSER=postgres PGPASSWORD=plu PGDATABASE=postgres ci/it-pgsql.sh
set -eu
cd "$(dirname "$0")/.."
. ci/env.sh

: "${PGHOST:?PGHOST is not set}"
: "${PGUSER:?PGUSER is not set}"
: "${PGDATABASE:?PGDATABASE is not set}"
export PGPORT="${PGPORT:-5432}"

n=0
until pg_isready -q -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE"; do
    n=$((n + 1))
    if [ $n -ge 60 ]; then
        echo "PostgreSQL at $PGHOST:$PGPORT did not become ready" >&2
        exit 1
    fi
    sleep 1
done

$SWIPL -q -g "load_files('pl_postgresql/test/it_pgsql.plt', [silent(true)]), run_tests" -t halt
