{ config, inputs, ... }:

let
  caddyModule = config.flake.modules.nixos.caddy;
in
{
  flake.modules.nixos.headscale =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.olympia.headscale;
    in
    {
      imports = [
        caddyModule
        inputs.forge.nixosModules.hetm
      ];

      options.olympia.headscale = {
        host = lib.mkOption {
          type = lib.types.str;
          description = "Public hostname used by Headscale.";
        };

        baseDomain = lib.mkOption {
          type = lib.types.str;
          description = "MagicDNS base domain.";
        };

        hetm = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable the Headscale pre-authentication key minter.";
          };

          audience = lib.mkOption {
            type = lib.types.str;
            description = "OIDC audience for hetm.";
          };

          host = lib.mkOption {
            type = lib.types.str;
            description = "Public hostname used by hetm.";
          };

          allow = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Allowed OIDC subject patterns.";
          };
        };
      };

      config = lib.mkMerge [
        {
          environment.etc."headscale/policy.hujson".source = ./headscale-policy.json;

          services.headscale = {
            enable = true;
            address = "127.0.0.1";
            port = 8080;

            settings = {
              server_url = "https://${cfg.host}";

              policy = {
                mode = "file";
                path = "/etc/headscale/policy.hujson";
              };

              prefixes = {
                v4 = "100.64.0.0/10";
              };

              dns = {
                magic_dns = true;
                base_domain = cfg.baseDomain;
                override_local_dns = true;

                nameservers.global = [
                  "1.1.1.1"
                  "1.0.0.1"
                ];
              };
            };
          };

          systemd.services.headscale = {
            serviceConfig.ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
            reloadTriggers = [ ./headscale-policy.json ];
          };

          services.hetm = {
            enable = cfg.hetm.enable;

            inherit (cfg.hetm) audience allow;
          };

          services.caddy.virtualHosts = {
            "${cfg.host}".extraConfig = ''
              reverse_proxy ${config.services.headscale.address}:${toString config.services.headscale.port}
            '';
          }
          // lib.optionalAttrs cfg.hetm.enable {
            "${cfg.hetm.host}".extraConfig = ''
              reverse_proxy ${config.services.hetm.address}:${toString config.services.hetm.port}
            '';
          };
        }
        (lib.optionalAttrs (options.environment ? persistence) {
          environment.persistence.${config.olympia.persistencePath}.directories = [
            "/var/lib/headscale"
          ];
        })
      ];
    };

  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.olympia.tailscale;
    in
    {
      options.olympia.tailscale = {
        authKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Optional file containing a pre-authentication key.";
        };

        loginServer = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional custom coordination server URL.";
        };

        acceptDns = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether Tailscale should accept DNS settings from the coordination server.";
        };

        ssh = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether Tailscale SSH should serve SSH on the tailnet address.
            This only takes effect when {option}`authKeyFile` is set, because
            NixOS only applies `extraUpFlags` during auth-key login.
          '';
        };
      };

      config = lib.mkMerge [
        {
          assertions = lib.optional cfg.ssh {
            assertion = cfg.authKeyFile != null;
            message = "olympia.tailscale.ssh requires olympia.tailscale.authKeyFile, because NixOS only applies extraUpFlags during auth-key login.";
          };

          age.secrets.tailscale-auth-key = lib.mkIf (cfg.authKeyFile != null) {
            file = cfg.authKeyFile;
          };

          services.tailscale = {
            enable = true;
            openFirewall = true;

            authKeyFile = lib.mkIf (cfg.authKeyFile != null) config.age.secrets.tailscale-auth-key.path;

            extraUpFlags =
              lib.optional (cfg.loginServer != null) "--login-server=${cfg.loginServer}"
              ++ lib.optional (!cfg.acceptDns) "--accept-dns=false"
              ++ lib.optional cfg.ssh "--ssh";
          };
        }
        (lib.optionalAttrs (options.environment ? persistence) {
          environment.persistence.${config.olympia.persistencePath}.directories = [
            "/var/lib/tailscale"
          ];
        })
      ];
    };
}
