{ config, ... }:
let
  modules = config.flake.modules.nixos;
in
{
  hosts.heimdall = {
    system = "aarch64-linux";

    module = { config, ... }: {
      imports = [
        modules.base
        modules.core
        modules.ssh
        modules.oracle-ampere
        modules.headscale
        modules.tailscale
        modules.zfs
        modules.impermanent
      ];

      networking.hostId = "1206fe36";
      time.timeZone = "Europe/London";

      olympia.headscale = {
        host = "headscale.cleslie.uk";
        baseDomain = "net.cleslie.uk";

        hetm = {
          audience = "hetm.cleslie.uk";
          host = "hetm.cleslie.uk";
          allow = [
            "repo:callumio@16057677/olympia@1456726824:ref:refs/heads/main"
          ];
        };
      };

      olympia.tailscale = {
        authKeyFile = ../../secrets/tailscale-auth-bootstrap-key.age;
        loginServer = "https://${config.olympia.headscale.host}";
        acceptDns = false;
        ssh = true;
      };

      olympia.admins.admin = {
        description = "Admin user";
        extraGroups = [ "wheel" ];
        opensshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk"
        ];
        passwordFile = ../../secrets/heimdall-admin-pw.age;
      };

      olympia.deploy = {
        enable = true;
        hostname = "heimdall.net.cleslie.uk";
        publicKeys = [ ];
        sshOpts = [
          "-o"
          "StrictHostKeyChecking=accept-new"
        ];
      };

      olympia.storage = {
        disks.main = {
          device = "/dev/disk/by-id/wwn-0x602da4941f76473ab6648d624166ebf8";
          efi = true;
        };

        pools.rpool = {
          mode = "single";
          members = [ "main" ];
          profile = "impermanent";
        };
      };
    };
  };
}
