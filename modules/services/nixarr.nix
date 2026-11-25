{
  inputs,
  ...
}:

{
  flake.modules.nixos.nixarr =
    {
      config,
      pkgs,
      ...
    }:
    let
      # qBittorrent's internal API lives on the VPN namespace bridge when
      # confinement is enabled, and on localhost otherwise.
      qbitHost = if config.nixarr.qbittorrent.vpn.enable then "192.168.15.1" else "127.0.0.1";
    in
    {
      imports = [
        inputs.nixarr.nixosModules.default
      ];

      nixarr = {
        enable = true;

        # Media and persistent state live on the tank/persist datasets.
        mediaDir = "/tank/media";
        stateDir = "/persist/nixarr";

        sonarr = {
          enable = true;
          settings-sync.downloadClients = [
            {
              name = "qBittorrent";
              implementation = "QBittorrent";
              fields = {
                host = qbitHost;
                port = 8085;
                useSsl = false;
                tvCategory = "sonarr";
              };
            }
          ];
        };

        radarr = {
          enable = true;
          settings-sync.downloadClients = [
            {
              name = "qBittorrent";
              implementation = "QBittorrent";
              fields = {
                host = qbitHost;
                port = 8085;
                useSsl = false;
                movieCategory = "radarr";
              };
            }
          ];
        };

        lidarr.enable = true;

        prowlarr = {
          enable = true;
          settings-sync.enable-nixarr-apps = true;
        };

        bazarr = {
          enable = true;
          settings-sync = {
            sonarr.enable = true;
            radarr.enable = true;
          };
        };

        qbittorrent = {
          enable = true;
          qui.enable = true;
          # vpn.enable = true; # enable once nixarr.vpn.wgConf is configured
        };

        recyclarr = {
          enable = true;
          configuration = {
            sonarr.series = {
              base_url = "http://127.0.0.1:8989";
              api_key = "!env_var SONARR_API_KEY";
              quality_definition.type = "series";
            };

            radarr.movies = {
              base_url = "http://127.0.0.1:7878";
              api_key = "!env_var RADARR_API_KEY";
              quality_definition.type = "movie";
            };
          };
        };
      };

      # Nixarr's settings-sync uses the local APIs without authentication.
      services.sonarr.settings.auth.required = "DisabledForLocalAddresses";
      services.radarr.settings.auth.required = "DisabledForLocalAddresses";
      services.lidarr.settings.auth.required = "DisabledForLocalAddresses";
      services.prowlarr.settings.auth.required = "DisabledForLocalAddresses";

      systemd.tmpfiles.rules = [
        "d /persist/nixarr 0755 root root - -"
      ];

      # Nixarr's tmpfiles rules can run before the tank/media dataset is
      # mounted, so the real dataset may not get the library directories (or
      # may still have old ownership). Recreate them after the mount instead.
      systemd.services.nixarr-media-library = {
        description = "Ensure nixarr media library permissions";
        wantedBy = [ "multi-user.target" ];
        before = [
          "sonarr.service"
          "radarr.service"
          "lidarr.service"
          "qbittorrent.service"
          "bazarr.service"
        ];
        unitConfig.RequiresMountsFor = [ "/tank/media" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.coreutils}/bin/install -d -o root -g media -m 2775 \
            /tank/media \
            /tank/media/library \
            /tank/media/library/shows \
            /tank/media/library/movies
          ${pkgs.coreutils}/bin/install -d -o root -g media -m 0775 \
            /tank/media/library/music

          for dir in \
            /tank/media/qbittorrent \
            /tank/media/qbittorrent/.incomplete \
            /tank/media/qbittorrent/.watch \
            /tank/media/qbittorrent/manual \
            /tank/media/qbittorrent/lidarr \
            /tank/media/qbittorrent/radarr \
            /tank/media/qbittorrent/sonarr \
            /tank/media/qbittorrent/shelfmark; do
            ${pkgs.coreutils}/bin/install -d -o qbittorrent -g media -m 2775 "$dir"
          done
        '';
      };

      # qBittorrent otherwise creates group-readable-only files.
      systemd.services.qbittorrent.serviceConfig.UMask = "0002";

      # FlareSolverr is used by Prowlarr only. It listens locally; Prowlarr is
      # configured with http://127.0.0.1:8191 under Indexer Proxies.
      services.flaresolverr.enable = true;

      # Nixarr's private web UIs. qBittorrent's own WebUI stays internal to
      # 127.0.0.1:8085; users get qui on 5252.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
        8989 # Sonarr
        7878 # Radarr
        8686 # Lidarr
        9696 # Prowlarr
        6767 # Bazarr
        5252 # qui
      ];
    };
}
