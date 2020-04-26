with import <nixpkgs> {};

stdenv.mkDerivation rec {
    name = "env";

    #src = ./.;

    # Customizable development requirements
    nativeBuildInputs = [
        git
        gcc
        gprolog
        swiProlog
    ];

    buildInputs = [
        zlib
    ];

}

