#!/bin/sh
# Installs the modules built by ci/build.sh (or make.sh):
#
#   ci/install.sh [--init] [PREFIX]          (PREFIX defaults to $HOME)
#
#   PREFIX/lib/sbcl      SWI-Prolog foreign libraries and modules (.pl, .qlf),
#                        loaded as use_module(sbcl(toolbox)) etc.
#   PREFIX/lib/gprolog   GNU Prolog libraries (lib*-<arch>.a) to link with gplc
#
# --init adds the sbcl search path to ~/.config/swi-prolog/init.pl (once).
set -eu
cd "$(dirname "$0")/.."

init=0
if [ "${1:-}" = "--init" ]; then
    init=1
    shift
fi
PREFIX=${1:-$HOME}
ARCH=$(uname -s)
sbcl=$PREFIX/lib/sbcl
gp=$PREFIX/lib/gprolog

mkdir -p "$sbcl" "$gp"

for entry in pltoolbox:pl_toolbox plregexp:pl_regexp plcurl:pl_curl plpgsql:pl_postgresql; do
    lib=${entry%%:*}
    dir=${entry##*:}
    cp "$dir/$lib-$ARCH" "$sbcl/$lib"
done
# the sources too: SWI-Prolog uses a .qlf only as a cache of its .pl file;
# a .qlf on its own breaks when two modules load the same library.
# Sources first, so that the .qlf files are newer.
cp pl_toolbox/src/toolbox.pl pl_toolbox/src/math.pl pl_toolbox/src/string.pl \
   pl_toolbox/src/stream.pl pl_toolbox/src/vector.pl pl_toolbox/src/json.pl \
   pl_regexp/src/regexp.pl pl_cgi/src/cgi.pl pl_cgi/src/common.pl \
   pl_curl/src/curl.pl pl_postgresql/src/pgsql.pl "$sbcl/"
cp pl_toolbox/src/toolbox.qlf pl_regexp/src/regexp.qlf pl_cgi/src/cgi.qlf \
   pl_curl/src/curl.qlf pl_postgresql/src/pgsql.qlf "$sbcl/"
cp pl_toolbox/libpltoolbox-"$ARCH".a pl_regexp/libplregexp-"$ARCH".a \
   pl_cgi/libplcgi-"$ARCH".a pl_curl/libplcurl-"$ARCH".a "$gp/"

if [ "$init" -eq 1 ]; then
    rc=$HOME/.config/swi-prolog/init.pl
    marker="% prolog-utilities: sbcl search path"
    mkdir -p "$(dirname "$rc")"
    if ! grep -qF "$marker" "$rc" 2>/dev/null; then
        cat >> "$rc" <<EOF
$marker
:- multifile user:file_search_path/2.
:- dynamic user:file_search_path/2.
user:file_search_path(sbcl, '$sbcl').
EOF
    fi
fi

echo "installed into $sbcl and $gp"
