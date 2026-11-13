{ config, inputs, ... }:

let
  lib = inputs.nixpkgs.lib;

  mkAdminUsers =
    admins: name:
    lib.mapAttrsToList (username: user: {
      age.secrets."${name}-${username}-pw".file = ../../secrets + "/${name}-${username}-pw.age";
      users.users.${username} = {
        isNormalUser = true;
        inherit (user) description;

        home = "/home/${username}";
        createHome = true;

        inherit (user) extraGroups;

        openssh.authorizedKeys.keys = user.opensshKeys;
        passwordFile = config.age.secrets."${name}-${username}-pw".path;
      };
    }) admins;

  mkDeployUser =
    host:
    lib.optional host.deploy.enable {
      users.users.${host.deploy.user} = {
        isNormalUser = true;
        description = "Deployment user";

        home = "/home/${host.deploy.user}";
        createHome = true;

        openssh.authorizedKeys.keys = host.deploy.publicKeys;
      };

      nix.settings.trusted-users = [
        host.deploy.user
      ];

      security.sudo.extraRules = [
        {
          users = [ host.deploy.user ];

          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };

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
        inputs.disko.nixosModules.disko

        config.flake.modules.nixos.storage-options
        config.flake.modules.nixos.storage-disko
        {
          mySystem.storage = host.storage;
          networking.hostId = host.hostId;
          networking.hostName = name;
          time.timeZone = host.timeZone;
          users.mutableUsers = false;
        }
      ]
      ++ lib.optional (host.storage.pools != { }) config.flake.modules.nixos.zfs
      ++ lib.optional (lib.any (pool: pool.profile == "impermanent") (
        lib.attrValues host.storage.pools
      )) config.flake.modules.nixos.impermanent
      ++ host.modules
      ++ mkAdminUsers host.admins name
      ++ mkDeployUser host;
    }
  ) config.hosts;
}
