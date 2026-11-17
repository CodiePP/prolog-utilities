#!/bin/sh
# Installs everything needed to build and test all modules on Debian/Ubuntu:
# toolchain, SWI-Prolog, libcurl, libpq and GNU Prolog.
# Runs as root or through sudo. Used by the GitHub workflows and the
# Dockerfile.
#
# SWI-Prolog is built from source too: Debian 13 ships 9.2.9, the stable
# (LTS) release is 10.0.x. The tarball is checked against the SHA-256 that
# swi-prolog.org publishes next to it.
#
# GNU Prolog is built from source: Debian 13 and Ubuntu 24.04 have no arm64
# package and only 1.4.5 for amd64. The release tarball is checked against
# its SHA-256 (taken from the GPG-verified release, signed by Daniel Diaz).
set -eu

SWIPL_VERSION=10.0.2
SWIPL_SHA256=e42cc098f7b8a6051c4f79a99b55162d467098aba60f69649bdc7583f0734b57
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
    ca-certificates \
    curl \
    cmake \
    ninja-build \
    libgmp-dev \
    libedit-dev \
    libpcre2-dev \
    libcurl4-openssl-dev \
    libpq-dev \
    libssl-dev \
    zlib1g-dev \
    postgresql-client

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if swipl --version 2>/dev/null | grep -q " ${SWIPL_VERSION} "; then
    echo "SWI-Prolog already installed: $(swipl --version)"
else
    (
        cd "$tmp"
        curl -fsSLO "https://www.swi-prolog.org/download/stable/src/swipl-${SWIPL_VERSION}.tar.gz"
        echo "${SWIPL_SHA256}  swipl-${SWIPL_VERSION}.tar.gz" | sha256sum -c -
        tar xzf "swipl-${SWIPL_VERSION}.tar.gz"
        cd "swipl-${SWIPL_VERSION}"
        # no GUI, Java, ODBC or documentation: the modules here need only
        # the core system and its headers
        cmake -S . -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/usr/local \
            -DINSTALL_DOCUMENTATION=OFF \
            -DSWIPL_PACKAGES_X=OFF \
            -DSWIPL_PACKAGES_JAVA=OFF \
            -DSWIPL_PACKAGES_ODBC=OFF \
            -DBUILD_TESTING=OFF
        cmake --build build
        $SUDO cmake --install build
    )
    $SUDO ldconfig
    swipl --version
fi

if command -v gplc >/dev/null 2>&1; then
    echo "GNU Prolog already installed: $(gplc --version | head -1)"
    exit 0
fi

cd "$tmp"
curl -fsSLO "https://ftp.gnu.org/gnu/gprolog/gprolog-${GPROLOG_VERSION}.tar.gz"
echo "${GPROLOG_SHA256}  gprolog-${GPROLOG_VERSION}.tar.gz" | sha256sum -c -
tar xzf "gprolog-${GPROLOG_VERSION}.tar.gz"
cd "gprolog-${GPROLOG_VERSION}/src"
./configure
# no "make -j": gplc derives its intermediate file names from
# time(NULL) ^ getpid() and does not create them exclusively, so parallel
# gplc runs (e.g. in Fd2C) can share temporary files and corrupt each other
make
$SUDO make install
gplc --version | head -1
