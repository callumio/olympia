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

    services.headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 8080;
      settings.server_url = "https://${config.mySystem.headscale.host}";
      settings.dns = {
        base_domain = "net.cleslie.uk";
      };
    };

    environment.persistence."/persist".directories = [
      "/var/lib/headscale"
    ];
  };

  flake.modules.nixos.tailscale = { config, ... }: {
    options.mySystem.tailscale.authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional file containing a Headscale pre-authentication key.";
    };

    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.mySystem.tailscale.authKeyFile;
      extraUpFlags = [
        "--login-server=${headscaleUrl}"
      ];
    };

    environment.persistence."/persist".directories = [
      "/var/lib/tailscale"
    ];
  };

}
