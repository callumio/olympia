{ config, inputs, ... }:

let
  lib = inputs.nixpkgs.lib;

  deployableHosts = lib.filterAttrs (_: host: host.deploy.enable) config.hosts;

in
{
  flake.deploy.nodes = builtins.mapAttrs (name: host: {
    hostname = host.deploy.hostname;

    profiles.system = {
      user = "root";
      sshUser = host.deploy.user;

      path = inputs.deploy-rs.lib.${host.system}.activate.nixos config.flake.nixosConfigurations.${name};

      magicRollback = true;
      autoRollback = true;
    };
  }) deployableHosts;
}
