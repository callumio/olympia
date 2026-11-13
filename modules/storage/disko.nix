_:

{
  flake.modules.nixos.storage-disko =
    { config, lib, ... }:

    let
      storage = config.mySystem.storage;

      diskPool =
        diskName:
        let
          matches = lib.filterAttrs (_: pool: builtins.elem diskName pool.members) storage.pools;
        in
        if builtins.length (lib.attrNames matches) != 1 then
          throw "Disk ${diskName} must belong to exactly one pool"
        else
          builtins.head (lib.attrNames matches);

      diskConfigs = lib.mapAttrs (
        diskName: disk:
        let
          poolName = diskPool diskName;
        in
        {
          type = "disk";
          inherit (disk) device;

          content = {
            type = "gpt";

            partitions =
              (lib.optionalAttrs disk.efi {
                ESP = {
                  size = "512M";
                  type = "EF00";

                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };
              })
              // {
                zfs = {
                  size = "100%";

                  content = {
                    type = "zfs";
                    pool = poolName;
                  };
                };
              };
          };
        }
      ) storage.disks;

      poolConfigs = lib.mapAttrs (poolName: pool: {
        type = "zpool";

        mode = if pool.mode == "single" then "" else pool.mode;

        options.ashift = "12";

        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          mountpoint = "none";
        };

        datasets =
          if pool.profile == "impermanent" then
            {
              root = {
                type = "zfs_fs";
                mountpoint = "/";
                options.mountpoint = "legacy";

                postCreateHook = ''
                  zfs list -t snapshot -H -o name |
                    grep -qx '${poolName}/root@blank' ||
                    zfs snapshot ${poolName}/root@blank
                '';
              };

              nix = {
                type = "zfs_fs";
                mountpoint = "/nix";
                options.mountpoint = "legacy";
              };

              persist = {
                type = "zfs_fs";
                mountpoint = "/persist";
                options.mountpoint = "legacy";
                options.canmount = "on";
              };
            }
          else
            { };
      }) storage.pools;

      poolAssertions = lib.mapAttrsToList (name: pool: {
        assertion =
          (
            if pool.mode == "single" then
              builtins.length pool.members == 1
            else if pool.mode == "raidz1" then
              builtins.length pool.members >= 2
            else
              builtins.length pool.members >= 3
          )
          && (pool.profile != "impermanent" || (name == "rpool" && pool.mode == "single"));

        message = "Invalid topology or profile for ZFS pool ${name}.";
      }) storage.pools;

    in
    {
      disko.devices = {
        disk = diskConfigs;
        zpool = poolConfigs;
      };

      assertions = poolAssertions ++ [
        {
          assertion = lib.all (diskName: builtins.hasAttr diskName storage.disks) (
            lib.concatMap (pool: pool.members) (lib.attrValues storage.pools)
          );

          message = "A ZFS pool references an undefined disk.";
        }
      ];
    };
}
