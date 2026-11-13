{ config, ... }:

{
  hosts.atlas = {
    system = "x86_64-linux";

    modules = [
      config.flake.modules.nixos.core
      config.flake.modules.nixos.ssh
      config.flake.modules.nixos.timezone
    ];

    timeZone = "Europe/London";

    admins = {
      admin = {
        description = "Admin user";
        extraGroups = [ "wheel" ];
        opensshKeys = [ ];
      };
    };

    deploy = {
      enable = true;
      hostname = "atlas";
      publicKeys = [ ];
    };

    storage = {
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
}
