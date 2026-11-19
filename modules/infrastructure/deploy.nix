{ config, inputs, ... }:
let
  lib = inputs.nixpkgs.lib;

  deployableHosts = lib.filterAttrs (
    _: host: host.config.olympia.deploy.enable
  ) config.flake.nixosConfigurations;
in
{
  flake.deploy.nodes = builtins.mapAttrs (name: host: {
    hostname =
      if host.config.olympia.deploy.hostname != null then host.config.olympia.deploy.hostname else name;

    profiles.system = {
      user = "root";
      sshUser = host.config.olympia.deploy.user;
      sshOpts = host.config.olympia.deploy.sshOpts;

      path = inputs.deploy-rs.lib.${host.config.nixpkgs.system}.activate.nixos host;

      magicRollback = true;
      autoRollback = true;
    };
  }) deployableHosts;
}
