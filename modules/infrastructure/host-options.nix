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

          module = lib.mkOption {
            type = lib.types.deferredModule;
            description = "NixOS module defining this host.";
          };
        };
      }
    );

    default = { };
  };
}
