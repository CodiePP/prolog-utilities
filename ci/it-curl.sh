#!/bin/sh
# pl_curl integration tests: starts pl_curl/test/http_fixture.pl (a small
# SWI-Prolog HTTP and WebSocket server), runs pl_curl/test/it_curl.plt and
# it_curl_ws.plt (SWI-Prolog) and it_curl_ws_gp.pl (GNU Prolog) against it,
# stops it. Needs a finished ci/build.sh.
# Environment: FIXTURE_PORT (default 18080); PL_CURL_WS_OPTIONAL=1 skips the
# WebSocket tests instead of failing when libcurl lacks WebSocket support.
set -eu
cd "$(dirname "$0")/.."
. ci/env.sh

FIXTURE_PORT=${FIXTURE_PORT:-18080}
export FIXTURE_PORT

$SWIPL -q pl_curl/test/http_fixture.pl "$FIXTURE_PORT" &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT INT TERM

# wait up to 20s for the server
n=0
until curl -fsS "http://127.0.0.1:$FIXTURE_PORT/get" >/dev/null 2>&1; do
    n=$((n + 1))
    if [ $n -ge 40 ] || ! kill -0 $server 2>/dev/null; then
        echo "fixture did not start" >&2
        exit 1
    fi
    sleep 0.5
done

$SWIPL -q -g "load_files('pl_curl/test/it_curl.plt', [silent(true)]), run_tests" -t halt
$SWIPL -q -g "load_files('pl_curl/test/it_curl_ws.plt', [silent(true)]), run_tests" -t halt

# the same WebSocket predicates through the GNU Prolog bridge
if [ "${PL_CURL_WS_OPTIONAL:-}" = 1 ] && ! $SWIPL -q -g "
        load_files('pl_curl/test/it_curl_ws.plt', [silent(true)]),
        ( ws_available -> halt(0) ; halt(1) )" -t halt; then
    echo "libcurl without WebSocket support: GNU Prolog WebSocket tests skipped"
    exit 0
fi
mkdir -p build
gplc -o build/it_curl_ws_gp pl_curl/test/it_curl_ws_gp.pl \
     "pl_curl/libplcurl-$ARCH.a" -L '-lcurl -pthread'
./build/it_curl_ws_gp
