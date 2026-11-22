{ config, ... }:
let
  caddyModule = config.flake.modules.nixos.caddy;
in
{
  flake.modules.nixos.homepage =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.olympia.homepage;

      entryType = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to show this service on Homepage.";
          };

          name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Display name. Defaults to the entry key.";
          };

          href = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Link target. Defaults to https://<entry key>.";
          };

          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Short description shown under the service name.";
          };

          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Homepage icon name or URL.";
          };

          group = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Homepage group. Defaults to olympia.homepage.group.";
          };

          settings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra Homepage service settings merged into the entry.";
          };
        };
      };

      caddyHosts = lib.filterAttrs (host: _: host != cfg.host) config.services.caddy.virtualHosts;

      entryIds = lib.unique (builtins.attrNames caddyHosts ++ builtins.attrNames cfg.entries);

      mkEntry =
        id:
        let
          entry = cfg.entries.${id} or { };
          name = if entry.name or null != null then entry.name else id;
          href = if entry.href or null != null then entry.href else "https://${id}";
          group = if entry.group or null != null then entry.group else cfg.group;
        in
        if !(entry.enable or true) then
          null
        else
          {
            inherit group;
            value = {
              ${name} = {
                inherit href;
                description = entry.description or "";
              }
              // lib.optionalAttrs (entry.icon or null != null) {
                inherit (entry) icon;
              }
              // (entry.settings or { });
            };
          };

      entries = lib.filter (entry: entry != null) (map mkEntry entryIds);

      groupedEntries = lib.groupBy (entry: entry.group) entries;
    in
    {
      imports = [
        caddyModule
      ];

      options.olympia.homepage = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable the Homepage dashboard.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          description = "Public hostname used by Homepage.";
        };

        title = lib.mkOption {
          type = lib.types.str;
          default = "Homepage";
          description = "Title shown in the Homepage header.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "Services";
          description = "Default group for generated service entries.";
        };

        entries = lib.mkOption {
          type = lib.types.attrsOf entryType;
          default = { };
          description = ''
            Overrides for Homepage service entries, keyed by Caddy virtual host.
            Every Caddy virtual host gets an entry by default. Set
            {option}`enable` to false for services without a web UI.
          '';
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          services.caddy.virtualHosts.${cfg.host}.extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.homepage-dashboard.listenPort}
          '';

          services.homepage-dashboard = {
            enable = true;

            allowedHosts = lib.mkDefault "${cfg.host},localhost:${toString config.services.homepage-dashboard.listenPort},127.0.0.1:${toString config.services.homepage-dashboard.listenPort}";

            settings.title = lib.mkDefault cfg.title;

            services = lib.mapAttrsToList (group: groupEntries: {
              ${group} = map (entry: entry.value) groupEntries;
            }) groupedEntries;
          };
        })
        (lib.mkIf (cfg.enable && (options.environment ? persistence)) {
          environment.persistence.${config.olympia.persistencePath}.directories = [
            "/var/lib/homepage-dashboard"
          ];
        })
      ];
    };
}
