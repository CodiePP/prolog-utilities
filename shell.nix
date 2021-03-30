with import <nixpkgs> {};

stdenv.mkDerivation rec {
    name = "env";

    #src = ./.;

    # Customizable development requirements
    nativeBuildInputs = [
        automake
        autoconf
        pkg-config
        postgresql
        gcc
        gprolog
        swiProlog
    ];

    buildInputs = [
        zlib
        openssl
    ];

}

