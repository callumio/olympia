{ lib, ... }:

let
  headscaleHost = "headscale.cleslie.uk";
  headscaleUrl = "https://${headscaleHost}";
in
{
  flake.modules.nixos.headscale = { config, ... }: {
    options.mySystem.headscale.host = lib.mkOption {
      type = lib.types.str;
      default = headscaleHost;
      description = "Public hostname used by Headscale.";
    };

    config = {
      services.headscale = {
        enable = true;
        address = "127.0.0.1";
        port = 8080;
        settings.server_url = "https://${config.mySystem.headscale.host}";
        settings.prefixes = {
          v4 = "100.64.0.0/10";
        };
        settings.dns = {
          magic_dns = true;
          base_domain = "net.cleslie.uk";
          override_local_dns = true;
          nameservers.global = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        };
      };

      environment.persistence."/persist".directories = [
        "/var/lib/headscale"
      ];
    };
  };

  flake.modules.nixos.tailscale = { config, ... }: {
    options.mySystem.tailscale.headscaleServer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this host also runs the Headscale server.";
    };

    options.mySystem.tailscale.authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional file containing a Headscale pre-authentication key.";
    };

    config = {
      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = config.mySystem.tailscale.authKeyFile;
        extraUpFlags =
          [
            "--login-server=${headscaleUrl}"
          ]
          ++ lib.optional config.mySystem.tailscale.headscaleServer "--accept-dns=false";
      };

      environment.persistence."/persist".directories = [
        "/var/lib/tailscale"
      ];
    };
  };

}
