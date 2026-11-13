{ config, ... }:

{
  hosts.heimdall = {
    system = "aarch64-linux";

    modules = [
      config.flake.modules.nixos.core
      config.flake.modules.nixos.ssh
      config.flake.modules.nixos.timezone
      config.flake.modules.nixos.oracle-ampere
    ];

    timeZone = "Europe/London";

    admins = {
      admin = {
        description = "Admin user";
        extraGroups = [ "wheel" ];
        opensshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk" ];
      };
    };

    deploy = {
      enable = true;
      hostname = "heimdall";
      publicKeys = [ ];
    };

    hostId = "1206fe36";

    storage = {
      disks.main = {
        device = "/dev/disk/by-id/wwn-0x60c46a563ef2411784ebcda2dd53a2fe";
        efi = true;
      };

      pools.rpool = {
        mode = "single";
        members = [ "main" ];
        profile = "impermanent";
      };
    };
  };
}
