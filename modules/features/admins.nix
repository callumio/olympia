_:

{
  flake.modules.nixos.admins =
    { config, lib, ... }:
    let
      cfg = config.olympia.admins;
      hostName = config.networking.hostName;
      secretName = username: "${hostName}-${username}-pw";
    in
    {
      options.olympia.admins = lib.mkOption {
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

              passwordFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Encrypted password file. If null, no password is configured.";
              };
            };
          }
        );

        default = { };
      };

      config = lib.mkIf (cfg != { }) {
        age.secrets = lib.mapAttrs' (
          username: user:
          lib.nameValuePair (secretName username) {
            file = user.passwordFile;
          }
        ) (lib.filterAttrs (_: user: user.passwordFile != null) cfg);

        users.users = lib.mapAttrs (
          username: user:
          {
            isNormalUser = true;

            inherit (user) description extraGroups;

            home = "/home/${username}";
            createHome = true;

            openssh.authorizedKeys.keys = user.opensshKeys;
          }
          // lib.optionalAttrs (user.passwordFile != null) {
            hashedPasswordFile = config.age.secrets.${secretName username}.path;
          }
        ) cfg;
      };
    };
}
