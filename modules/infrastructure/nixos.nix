{ config, inputs, ... }:

let
  lib = inputs.nixpkgs.lib;

  mkAdminUsers =
    admins: name:
    lib.mapAttrsToList (username: user: {config, ...}: let secret = "${name}-${username}-pw"; in{
      age.secrets."${name}-${username}-pw".file = ../../secrets + "/${secret}.age";
      users.users.${username} = {
        isNormalUser = true;
        inherit (user) description;

        home = "/home/${username}";
        createHome = true;

        inherit (user) extraGroups;

        openssh.authorizedKeys.keys = user.opensshKeys;
        hashedPasswordFile = config.age.secrets."${secret}".path;
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

  mkTailscale =
    name: host:
    lib.optional host.tailscale.enable (
      { config, ... }:
      {
        imports = [
          flakeModules.tailscale
        ];

        age.secrets.tailscale-auth-key = {
          file = host.tailscale.authKeyFile;
        };

        mySystem.tailscale.authKeyFile = config.age.secrets.tailscale-auth-key.path;
        mySystem.tailscale.headscaleServer = host.headscale.enable;
      }
    );

  mkHeadscale =
    host:
    lib.optional host.headscale.enable (
      { config, ... }:
      {
        imports = [
          flakeModules.headscale
        ] ++ lib.optional host.headscale.proxy.enable flakeModules.caddy;

        mySystem.caddy.virtualHosts = lib.mkIf host.headscale.proxy.enable {
          "${config.mySystem.headscale.host}".extraConfig = ''
            reverse_proxy ${config.services.headscale.address}:${toString config.services.headscale.port}
          '';
        };
      }
    );

  mkCaddy =
    host:
    lib.optional host.caddy.enable (
      {
        imports = [
          flakeModules.caddy
        ];

        mySystem.caddy.virtualHosts = host.caddy.virtualHosts;
      }
    );

  flakeModules = config.flake.modules.nixos;

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
        inputs.agenix.nixosModules.default

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
      ++ mkHeadscale host
      ++ mkCaddy host
      ++ mkTailscale name host
      ++ mkAdminUsers host.admins name
      ++ mkDeployUser host;
    }
  ) config.hosts;
}
