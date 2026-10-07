#!/bin/sh
# Builds every module: SWI-Prolog shared objects, GNU Prolog libraries and
# the .qlf files. Run from anywhere; works on a clean checkout.
set -eu
cd "$(dirname "$0")/.."
. ci/env.sh

# The foreign libraries are loaded as sbcl(<name>) without an extension.
# Link them into the staging directory up front: the Makefiles qcompile the
# Prolog side right after linking the library, and that needs to load it.
mkdir -p "$PLU_STAGE"
for entry in pltoolbox:pl_toolbox plregexp:pl_regexp plcurl:pl_curl plpgsql:pl_postgresql; do
    lib=${entry%%:*}
    dir=${entry##*:}
    ln -sf "$PLU_ROOT/$dir/$lib-$ARCH" "$PLU_STAGE/$lib"
done

for m in pl_toolbox pl_regexp pl_cgi pl_curl; do
    echo "::: building $m"
    make -C "$m" SWIPL="$SWIPL"
done

echo "::: building pl_postgresql"
(
    cd pl_postgresql
    # also installs current config/install-sh, config.guess, config.sub
    autoreconf -fi
    ./configure
    make SWIPL="$SWIPL" CFLAGS="-g -O2 -fPIC -Wall"
)

# fail loudly if a library is missing (a failed link would otherwise only
# show up as a confusing load error in the tests)
for lib in pltoolbox plregexp plcurl plpgsql; do
    test -e "$PLU_STAGE/$lib" || { echo "missing foreign library: $lib" >&2; exit 1; }
done
echo "::: build ok"
