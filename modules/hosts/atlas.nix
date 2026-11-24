{config, ...}: let
  modules = config.flake.modules.nixos;
in {
  hosts.atlas = {
    system = "x86_64-linux";

    module = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        modules.base
        modules.core
        modules.ssh
        modules.tailscale
        modules.zfs
        modules.impermanent
      ];

      networking.hostId = "3b879400";
      time.timeZone = "Europe/London";

      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };

      olympia.tailscale = {
        authKeyFile = ../../secrets/tailscale-auth-bootstrap-key.age;
        loginServer = "https://${config.olympia.headscale.host}";
        acceptDns = false;
        ssh = true;
      };

      olympia.admins.admin = {
        description = "Admin user";
        extraGroups = ["wheel"];
        opensshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk"
        ];
        passwordFile = ../../secrets/atlas-admin-pw.age;
      };

      olympia.deploy = {
        enable = true;
        hostname = "atlas.net.cleslie.uk";
        publicKeys = [];
        sshOpts = [
          "-o"
          "StrictHostKeyChecking=accept-new"
        ];
      };

      olympia.storage = {
        disks = {
          boot = {
            device = "/dev/disk/by-id/ata-Samsung_SSD_840_EVO_120GB_S1D5NSAF662893M";
            efi = true;
          };

          data1.device = "/dev/disk/by-id/wwn-0x5000cca2677638a4";
          data2.device = "/dev/disk/by-id/wwn-0x5000cca26776f204";
          data3.device = "/dev/disk/by-id/wwn-0x5000cca26776f660";
          data4.device = "/dev/disk/by-id/wwn-0x5000cca26776f8e8";
        };

        pools = {
          rpool = {
            mode = "single";
            members = ["boot"];
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
