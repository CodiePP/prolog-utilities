# Development shell with everything needed to build and test all modules:
#
#   nix-shell            then: ci/build.sh && ci/test.sh
#
# nixpkgs is pinned (nixos-26.05 as of 2026-10-07), so every checkout gets the
# same toolchain. To update, take the revision from
# https://channels.nixos.org/nixos-<release>/git-revision and the hash from
#   nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/<rev>.tar.gz
{ pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/2efa67fd26b6df417c33e4603185c701f260dd83.tar.gz";
    sha256 = "0y0ars4h19fiprdfcjcdiqylm9hwcy6zy8h9nnskwjzchapsmgdz";
  }) {}
}:

pkgs.mkShell {
    # build tools
    nativeBuildInputs = with pkgs; [
        autoconf
        automake
        gnumake
        pkg-config
        gprolog
        swi-prolog
        postgresql      # pg_isready / psql for ci/it-pgsql.sh
    ];

    # libraries the foreign modules link against
    buildInputs = with pkgs; [
        curl            # pl_curl
        libpq           # pl_postgresql
        openssl         # pl_postgresql/configure checks libssl/libcrypto
        zlib
    ];
}
