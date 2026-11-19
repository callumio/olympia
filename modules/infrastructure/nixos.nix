{ config, inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
in
{
  flake.nixosConfigurations = lib.mapAttrs (
    name: host:
    inputs.nixpkgs.lib.nixosSystem {
      inherit (host) system;

      specialArgs = {
        inherit inputs;
      };

      modules = [
        {
          networking.hostName = name;
        }
        host.module
      ];
    }
  ) config.hosts;
}
