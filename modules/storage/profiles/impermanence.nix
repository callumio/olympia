{ inputs, ... }:

{
  flake.modules.nixos.impermanent = { config, ... }: {
    imports = [
      inputs.impermanence.nixosModules.impermanence
    ];
    fileSystems."/persist".neededForBoot = true;

    boot.initrd.systemd = {
      services.rollback = {
        description = "Rollback root filesystem to blank";

        wantedBy = [ "initrd.target" ];

        after = [
          "zfs-import-rpool.service"
        ];

        before = [
          "sysroot.mount"
        ];

        path = [
          config.boot.zfs.package
        ];

        unitConfig.DefaultDependencies = "no";

        serviceConfig.Type = "oneshot";

        script = ''
          zfs rollback -r rpool/root@blank
        '';
      };
    };

    environment.persistence."/persist" = {
      hideMounts = true;

      directories = [
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/log"
        "/etc/ssh"
      ];

      files = [
        "/etc/machine-id"
      ];
    };
  };
}
