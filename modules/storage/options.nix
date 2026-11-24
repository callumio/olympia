_:

{
  flake.modules.nixos.storage-options = { lib, ... }: {
    options.olympia.storage = {
      disks = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              device = lib.mkOption {
                type = lib.types.strMatching "^/dev/disk/by-id/.+";
              };

              efi = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Create a FAT32 boot partition for /boot.";
              };

              biosBoot = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Create a BIOS boot partition for GRUB on legacy BIOS systems.";
              };
            };
          }
        );
      };

      pools = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              mode = lib.mkOption {
                type = lib.types.enum [
                  "single"
                  "raidz1"
                  "raidz2"
                ];
              };

              members = lib.mkOption {
                type = lib.types.listOf lib.types.str;
              };

              profile = lib.mkOption {
                type = lib.types.enum [
                  "impermanent"
                  "none"
                ];
                default = "none";
              };

              datasets = lib.mkOption {
                default = { };
                description = "Extra ZFS datasets for this pool.";
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      mountpoint = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "Path to mount the dataset to. Null creates the dataset without a mount point.";
                      };

                      options = lib.mkOption {
                        type = lib.types.attrsOf lib.types.str;
                        default = { };
                        description = "ZFS dataset properties, for example recordsize or compression.";
                      };
                    };
                  }
                );
              };
            };
          }
        );
      };
    };
  };
}
