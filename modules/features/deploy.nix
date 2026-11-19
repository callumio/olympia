_:

{
  flake.modules.nixos.deploy =
    { config, lib, ... }:
    let
      cfg = config.olympia.deploy;
    in
    {
      options.olympia.deploy = {
        enable = lib.mkEnableOption "deployment";

        hostname = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSH hostname used by deploy-rs. Defaults to the host attribute name.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "deploy";
          description = "User deploy-rs connects as.";
        };

        publicKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys allowed to deploy to this host.";
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.${cfg.user} = {
          isNormalUser = true;
          description = "Deployment user";

          home = "/home/${cfg.user}";
          createHome = true;

          openssh.authorizedKeys.keys = cfg.publicKeys;
        };

        nix.settings.trusted-users = [
          cfg.user
        ];

        security.sudo.extraRules = [
          {
            users = [ cfg.user ];

            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };
    };
}
