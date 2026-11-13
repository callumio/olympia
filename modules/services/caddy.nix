{ lib, ... }:

{
  flake.modules.nixos.caddy = { config, ... }: {
    options.mySystem.caddy.virtualHosts = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Caddy virtual hosts.";
    };

    config = {
      services.caddy = {
        enable = true;
        email = "acme@cleslie.uk";
        virtualHosts = config.mySystem.caddy.virtualHosts;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    };
  };
}
