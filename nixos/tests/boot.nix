{ system ? builtins.currentSystem }:

with import ../lib/testing.nix { inherit system; };
with import ../lib/qemu-flags.nix;
with pkgs.lib;

let

  iso =
    (import ../lib/eval-config.nix {
      inherit system;
      modules =
        [ ../modules/installer/cd-dvd/installation-cd-minimal.nix
          ../modules/testing/test-instrumentation.nix
          { key = "serial"; }
        ];
    }).config.system.build.isoImage;

  makeBootTest = name: machineConfig:
    makeTest {
      inherit iso;
      name = "boot-" + name;
      nodes = { };
      testScript =
        ''
          my $machine = createMachine({ ${machineConfig}, qemuFlags => '-m 768' });
          $machine->start;
          $machine->waitForUnit("multi-user.target");
          $machine->shutdown;
        '';
    };
in {
    bootBiosCdrom = makeBootTest "bios-cdrom" ''
        cdrom => glob("${iso}/iso/*.iso")
      '';
    bootBiosUsb = makeBootTest "bios-usb" ''
        usb => glob("${iso}/iso/*.iso")
      '';
    bootUefiCdrom = makeBootTest "uefi-cdrom" ''
        cdrom => glob("${iso}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
    bootUefiUsb = makeBootTest "uefi-usb" ''
        usb => glob("${iso}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
  }

