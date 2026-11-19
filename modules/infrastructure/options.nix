_:

{
  flake.modules.nixos.options = { lib, ... }: {
    options.olympia = {
      persistencePath = lib.mkOption {
        type = lib.types.str;
        default = "/persist";
        description = "Mount point used for persistent state.";
      };

      secretsDir = lib.mkOption {
        type = lib.types.path;
        default = ../../secrets;
        description = "Directory containing agenix secret files.";
      };
    };
  };
}
