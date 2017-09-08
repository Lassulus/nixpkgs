{ stdenv, fetchurl, qt4, dbus, zlib, openssl, pkgconfig, readline, perl }:

stdenv.mkDerivation rec {
  name = "wvstreams-4.6.1";

  src = fetchurl {
    url = "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/wvstreams/${name}.tar.gz";
    sha256 = "0cvnq3mvh886gmxh0km858aqhx30hpyrfpg1dh6ara9sz3xza0w4";
  };

  patches = [
    ./chmod.patch
    ./gcc-6.patch
    #./magic.patch
    ./openssl-buildfix.patch
  ];

  preConfigure = ''
    find -type f | xargs sed -i 's@/bin/bash@bash@g'

    sed -e '1i#include <unistd.h>' -i $(find . -name '*.c' -o -name '*.cc')
  '';

  buildInputs = [ qt4 dbus zlib openssl readline perl ];

  meta = {
    description = "Network programming library in C++";
    homepage = http://alumnit.ca/wiki/index.php?page=WvStreams;
    license = "LGPL";
    maintainers = [ stdenv.lib.maintainers.marcweber ];
    platforms = stdenv.lib.platforms.linux;
  };
}
