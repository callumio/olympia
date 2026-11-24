_:

{
  flake.modules.nixos.arr =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      persist = config.olympia.persistencePath;

      persistenceDirectories = [
        {
          directory = "/var/lib/sonarr";
          user = "sonarr";
          group = "media";
          mode = "0700";
        }
        {
          directory = "/var/lib/radarr";
          user = "radarr";
          group = "media";
          mode = "0700";
        }
        {
          directory = "/var/lib/lidarr";
          user = "lidarr";
          group = "media";
          mode = "0700";
        }
        {
          directory = "/var/lib/prowlarr";
          user = "root";
          group = "root";
          mode = "0700";
        }
        {
          directory = "/var/lib/qBittorrent";
          user = "qbittorrent";
          group = "media";
          mode = "0700";
        }
        {
          directory = "/var/lib/qui";
          user = "qui";
          group = "media";
          mode = "0700";
        }
        {
          directory = "/var/lib/recyclarr";
          user = "recyclarr";
          group = "recyclarr";
          mode = "0700";
        }
      ];
    in
    lib.mkMerge [
      {
        # qBittorrent is still on the host network. It needs to be moved into
        # a WireGuard netns (or a Gluetun container) before it is used for
        # real downloads.
        users.groups.media = { };

        services = {
          sonarr = {
            enable = true;
            group = "media";
          };
          radarr = {
            enable = true;
            group = "media";
          };
          lidarr = {
            enable = true;
            group = "media";
          };
          prowlarr.enable = true;
          flaresolverr.enable = true;
          qbittorrent = {
            enable = true;
            group = "media";
          };

          qui = {
            enable = true;
            group = "media";
            secretFile = config.age.secrets.qui-session-secret.path;
            settings.host = "0.0.0.0";
          };

          recyclarr = {
            enable = true;
            configuration = {
              sonarr.main = {
                base_url = "http://127.0.0.1:8989";
                api_key._secret = "/persist/arr-keys/sonarr";
                quality_definition.type = "series";
              };

              radarr.main = {
                base_url = "http://127.0.0.1:7878";
                api_key._secret = "/persist/arr-keys/radarr";
                quality_definition.type = "movie";
              };
            };
          };
        };

        age.secrets.qui-session-secret.file = ../../secrets/qui-session-secret.age;

        # These are private services. They are reachable over the tailnet,
        # not from the public internet.
        #
        # qBittorrent's own WebUI is deliberately not exposed. qui is the
        # human-facing UI and talks to qBittorrent over localhost.
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
          8989 # Sonarr
          7878 # Radarr
          8686 # Lidarr
          9696 # Prowlarr
          7476 # qui
        ];

        # qBittorrent, Sonarr, Radarr and Lidarr all need to share
        # /tank/media so downloads can be hardlinked and moved atomically.
        systemd.services.media-permissions = {
          description = "Set media dataset permissions";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/tank/media" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            mkdir -p /tank/media/{downloads,movies,tv,music,books}
            chown root:media /tank/media /tank/media/{downloads,movies,tv,music,books}
            chmod 2775 /tank/media /tank/media/{downloads,movies,tv,music,books}
          '';
        };

        # Recyclarr needs the API keys that the *arr apps generate on first
        # start. Extract them from config.xml so we do not have to duplicate
        # secrets by hand.
        systemd.services.arr-api-keys = {
          description = "Extract *arr API keys for Recyclarr";
          wantedBy = [ "multi-user.target" ];
          after = [
            "sonarr.service"
            "radarr.service"
          ];
          wants = [
            "sonarr.service"
            "radarr.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.coreutils}/bin/install -d -m 0700 /persist/arr-keys

            for pair in \
              "sonarr:/var/lib/sonarr/.config/NzbDrone/config.xml" \
              "radarr:/var/lib/radarr/.config/Radarr/config.xml"; do
              name="''${pair%%:*}"
              file="''${pair#*:}"
              key=""

              for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
                if [ -f "$file" ]; then
                  key=$(${pkgs.gnused}/bin/sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "$file" | ${pkgs.coreutils}/bin/head -n1)
                  [ -n "$key" ] && break
                fi
                ${pkgs.coreutils}/bin/sleep 1
              done

              if [ -z "$key" ]; then
                echo "could not read $name API key from $file" >&2
                exit 1
              fi

              ${pkgs.coreutils}/bin/printf '%s' "$key" > "/persist/arr-keys/$name"
              ${pkgs.coreutils}/bin/chmod 0400 "/persist/arr-keys/$name"
            done
          '';
        };

        systemd.services.recyclarr.after = [ "arr-api-keys.service" ];
        systemd.services.recyclarr.requires = [ "arr-api-keys.service" ];
      }

      (lib.optionalAttrs (options.environment ? persistence) {
        environment.persistence.${persist}.directories = persistenceDirectories;
      })
    ];
}
