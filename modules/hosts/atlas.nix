{ config, ... }:

let
  modules = config.flake.modules.nixos;
in
{
  hosts.atlas = {
    system = "x86_64-linux";

    module = { ... }: {
      imports = [
        modules.base
        modules.core
        modules.ssh
        modules.zfs
        modules.impermanent
      ];

      networking.hostId = "1a2b3c4d";
      time.timeZone = "Europe/London";

      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };

      olympia.admins.admin = {
        description = "Admin user";
        extraGroups = [ "wheel" ];
        opensshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk"
        ];
      };

      olympia.deploy = {
        enable = true;
        hostname = "atlas";
        publicKeys = [ ];
      };

      olympia.storage = {
        disks = {
          boot = {
            device = "/dev/disk/by-id/boot-disk";
            efi = true;
          };

          data1.device = "/dev/disk/by-id/data-disk-1";
          data2.device = "/dev/disk/by-id/data-disk-2";
          data3.device = "/dev/disk/by-id/data-disk-3";
          data4.device = "/dev/disk/by-id/data-disk-4";
        };

        pools = {
          rpool = {
            mode = "single";
            members = [ "boot" ];
            profile = "impermanent";
          };

          tank = {
            mode = "raidz2";
            members = [
              "data1"
              "data2"
              "data3"
              "data4"
            ];
            profile = "none";
          };
        };
      };
    };
  };
}
