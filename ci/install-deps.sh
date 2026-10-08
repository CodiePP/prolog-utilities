#!/bin/sh
# Installs everything needed to build and test all modules on Debian/Ubuntu:
# toolchain, SWI-Prolog, libcurl, libpq, autotools and GNU Prolog.
# Runs as root or through sudo. Used by the GitHub workflows and the
# Dockerfile.
#
# GNU Prolog is built from source: Ubuntu 24.04 has no arm64 package and
# only 1.4.5 for amd64. The release tarball is checked against its SHA-256
# (taken from the GPG-verified release, signed by Daniel Diaz).
set -eu

GPROLOG_VERSION=1.5.0
GPROLOG_SHA256=670642b43c0faa27ebd68961efb17ebe707688f91b6809566ddd606139512c01

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO=sudo
fi

$SUDO apt-get update
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    autoconf \
    automake \
    m4 \
    ca-certificates \
    curl \
    swi-prolog-nox \
    libcurl4-openssl-dev \
    libpq-dev \
    libssl-dev \
    zlib1g-dev \
    postgresql-client

if command -v gplc >/dev/null 2>&1; then
    echo "GNU Prolog already installed: $(gplc --version | head -1)"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
curl -fsSLO "https://ftp.gnu.org/gnu/gprolog/gprolog-${GPROLOG_VERSION}.tar.gz"
echo "${GPROLOG_SHA256}  gprolog-${GPROLOG_VERSION}.tar.gz" | sha256sum -c -
tar xzf "gprolog-${GPROLOG_VERSION}.tar.gz"
cd "gprolog-${GPROLOG_VERSION}/src"
./configure
make -j"$(nproc)"
$SUDO make install
gplc --version | head -1
