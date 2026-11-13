_:

{
  flake.modules.nixos.storage-options = { lib, ... }: {
    options.mySystem.storage = {
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
            };
          }
        );
      };
    };
  };
}
