{ lib, ... }:

{
  options.hosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption {
            type = lib.types.enum [
              "x86_64-linux"
              "aarch64-linux"
            ];
          };

          modules = lib.mkOption {
            type = lib.types.listOf lib.types.deferredModule;
            default = [ ];
          };

          deploy = {
            enable = lib.mkEnableOption "deployment";

            hostname = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "deploy";
            };
            publicKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "SSH public keys allowed to deploy to this host.";
            };
          };

          timeZone = lib.mkOption {
            type = lib.types.str;
            default = "UTC";
            description = "System timezone.";
          };

          admins = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  description = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                  };

                  extraGroups = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ "wheel" ];
                  };

                  opensshKeys = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                  };
                };
              }
            );

            default = { };
          };

          hostId = lib.mkOption {
            type = lib.types.strMatching "[0-9a-f]{8}";
            description = "Unique ZFS host ID.";
          };

          storage = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Host storage configuration.";
          };

        };
      }
    );

    default = { };
  };

}
