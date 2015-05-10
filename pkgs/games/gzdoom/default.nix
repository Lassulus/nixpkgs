{stdenv, fetchgit, cmake, fmod, mesa, SDL2}:

stdenv.mkDerivation {
  name = "gzdoom-git";
  src = fetchgit {
    url = "https://github.com/coelckers/gzdoom";
    rev = "a59824cd8897dea5dd452c31be1328415478f990";
    sha256 = "64018b17e8669b120e30cd33ce6b6e59c87b2637bb677b944184762c2b1f34f5";
  };

  buildInputs = [cmake fmod mesa SDL2];

  cmakeFlags = [ "-DFMOD_LIBRARY=${fmod}/lib/libfmodex.so" ];

  preConfigure=''
    sed s@gzdoom.pk3@$out/share/gzdoom.pk3@ -i src/version.h
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp gzdoom $out/bin
    mkdir -p $out/share
    cp gzdoom.pk3 $out/share
  '';

  meta = {
    homepage = https://github.com/coelckers/gzdoom;
    description = "GZDoom adds an OpenGL renderer to the ZDoom source port.";
    maintainer = [ stdenv.lib.maintainers.lassulus ];
  };
}

