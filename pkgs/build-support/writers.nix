{ pkgs, lib }:

with lib;
rec {
  # Base implementation for non-compiled executables.
  # Takes an interpreter, for example `${pkgs.bash}/bin/bash`
  #
  # Examples:
  #   writebash = makeScriptWriter { interpreter = "${pkgs.bash}/bin/bash"; }
  #   makeScriptWriter { interpreter = "${pkgs.dash}/bin/dash"; } "hello" "echo hello world"
  makeScriptWriter = { interpreter, check ? null }: name: text:
    assert (with types; either absolute-pathname filename).check name;
    pkgs.write (baseNameOf name) {
      ${optionalString (types.absolute-pathname.check name) name} = {
        inherit check;
        executable = true;
        text = "#! ${interpreter}\n${text}";
      };
    };

  # Like writeScript but the first line is a shebang to bash
  #
  # Example:
  #   writeBash "example" ''
  #     echo hello world
  #   ''
  writeBash = pkgs.makeScriptWriter {
    interpreter = "${pkgs.bash}/bin/bash";
  };

  # Like writeScriptBIn but the first line is a shebang to bash
  writeBashBin = name:
    assert types.filename.check name;
    pkgs.writeBash "/bin/${name}";

  # writeC writes an executable c package called `name` to `destination` using `libraries`.
  #
  #  Examples:
  #    writeC "hello-world" { destination = "/bin/hello-world"; } ''
  #      include <stdio.h>
  #      int main() {
  #        printf("Hello World\n");
  #        return 0;
  #      }
  #    ''
  #
  #    writeC "hello-world-ncurses" { libraries = { ncurses = pkgs.ncurses; }; } ''
  #      #include <ncurses.h>
  #      int main() {
  #        initscr();
  #        printw("Hello World !!!");
  #        refresh(); endwin();
  #        return 0;
  #      }
  #    ''
  writeC = name: {
    libraries ? {}
  }: text: pkgs.runCommand name {
    inherit text;
    buildInputs = [ pkgs.pkgconfig ] ++ attrValues libraries;
    passAsFile = [ "text" ];
  } /* sh */ ''
    PATH=${makeBinPath [
      pkgs.binutils-unwrapped
      pkgs.coreutils
      pkgs.gcc
      pkgs.pkgconfig
    ]}
    exe=$out${destination}
    mkdir -p "$(dirname "$exe")"
    gcc \
        ${optionalString (libraries != [])
          /* sh */ "$(pkg-config --cflags --libs ${
            concatMapStringsSep " " escapeShellArg (attrNames libraries)
          })"
        } \
        -O \
        -o "$exe" \
        -Wall \
        -x c \
        "$textPath"
    strip --strip-unneeded "$exe"
  '';

  # Like writeScript but the first line is a shebang to dash
  #
  # Example:
  #   writeDash "example" ''
  #     echo hello world
  #   ''
  writeDash = pkgs.makeScriptWriter {
    interpreter = "${pkgs.dash}/bin/dash";
  };

  # Like writeScriptBin but the first line is a shebang to dash
  writeDashBin = name:
    assert types.filename.check name;
    pkgs.writeDash "/bin/${name}";


  # writeHaskell takes a name, an attrset with libraries and haskell version (both optional)
  # and some haskell source code and returns an executable.
  #
  # Example:
  #   writeHaskell "missiles" { libraries = [ pkgs.haskellPackages.acme-missiles ]; } ''
  #     Import Acme.Missiles
  #
  #     main = launchMissiles
  #   '';
  writeHaskell = name: {
    libraries ? {},
    ghc ? pkgs.ghc
  }: text: pkgs.runCommand name {
    inherit text;
    passAsFile = [ "text" ];
  } ''
    cp $text ${name}.hs
    ${ghc.withPackages (_: libraries )}/bin/ghc ${name}.hs
    cp ${name} $out
  '';

  writeHaskellBin = name: spec: text:
    pkgs.runCommand name {
    } ''
      mkdir -p $out/bin
      ln -s ${writeHaskell name spec text} $out/bin/name
    '';


  writeJS = name: { deps ? [] }: text:
  let
    node-env = pkgs.buildEnv {
      name = "node";
      paths = deps;
      pathsToLink = [
        "/lib/node_modules"
      ];
    };
  in pkgs.writeDash name ''
    export NODE_PATH=${node-env}/lib/node_modules
    exec ${pkgs.nodejs}/bin/node ${pkgs.writeText "js" text}
  '';

  writeJSBin = name:
    pkgs.writeJS "/bin/${name}";

  writePerl = name: { deps ? [] }:
  let
    perl-env = pkgs.buildEnv {
      name = "perl-environment";
      paths = deps;
      pathsToLink = [
        "/lib/perl5/site_perl"
      ];
    };
  in
  pkgs.makeScriptWriter {
    interpreter = "${pkgs.perl}/bin/perl -I ${perl-env}/lib/perl5/site_perl";
  } name;

  writePerlBin = name:
    pkgs.writePerl "/bin/${name}";

  writePython2 = name: { deps ? [], flakeIgnore ? [] }:
  let
    py = pkgs.python2.withPackages (ps: deps);
    ignoreAttribute = optionalString (flakeIgnore != []) "--ignore ${concatMapStringsSep "," escapeShellArg flakeIgnore}";
  in
  pkgs.makeScriptWriter {
    interpreter = "${py}/bin/python";
    check = pkgs.writeDash "python2check.sh" ''
      exec ${pkgs.python2Packages.flake8}/bin/flake8 --show-source ${ignoreAttribute} "$1"
    '';
  } name;

  writePython2Bin = name:
    pkgs.writePython2 "/bin/${name}";

  writePython3 = name: { deps ? [], flakeIgnore ? [] }:
  let
    py = pkgs.python3.withPackages (ps: deps);
    ignoreAttribute = optionalString (flakeIgnore != []) "--ignore ${concatMapStringsSep "," escapeShellArg flakeIgnore}";
  in
  pkgs.makeScriptWriter {
    interpreter = "${py}/bin/python";
    check = pkgs.writeDash "python3check.sh" ''
      exec ${pkgs.python3Packages.flake8}/bin/flake8 --show-source ${ignoreAttribute} "$1"
    '';
  } name;

  writePython3Bin = name:
    pkgs.writePython3 "/bin/${name}";
}
