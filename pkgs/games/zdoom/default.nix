{ stdenv, fetchgit, cmake, fmod, mesa, SDL2 }:

stdenv.mkDerivation {
  name = "zdoom-git";
  src = fetchgit {
    url = "https://github.com/rheit/zdoom";
    rev = "f10416af8a3faf223a3c49f3a08145554cc5c87f";
    sha256 = "ae9e178b1ee39d3abc31eaaac68e383fe217f439619206f52102d50437c5f39f";
  };

  buildInputs = [ cmake fmod mesa SDL2 ];

  cmakeFlags = [ "-DFMOD_LIBRARY=${fmod}/lib/libfmodex.so" ];
   
  preConfigure = ''
    sed s@zdoom.pk3@$out/share/zdoom.pk3@ -i src/version.h
 '';

  installPhase = ''
    mkdir -p $out/bin
    cp zdoom $out/bin
    mkdir -p $out/share
    cp zdoom.pk3 $out/share
  '';

  meta = {
    homepage = http://zdoom.org/;
    description = "Enhanced port of the official DOOM source code";
    maintainer = [ stdenv.lib.maintainers.lassulus ];
  };
}

