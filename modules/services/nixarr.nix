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

      # Strongly prefer x265/HEVC releases without making them mandatory.
      x265Score = 1000;
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

        vpn = {
          enable = true;
          wgConf = config.age.secrets.wg-conf.path;
        };

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
          vpn.enable = true;
          # No forwarded peer port from the VPN provider. qBittorrent will
          # still download/seed outbound, but it will not be connectable.
        };

        recyclarr = {
          enable = true;
          configuration = {
            sonarr.series = {
              base_url = "http://127.0.0.1:8989";
              api_key = "!env_var SONARR_API_KEY";
              quality_definition = {
                type = "series";
                # Cap 1080p at 90 MB/min (~10.8 GB for a 2-hour film).
                # Long or very grainy films legitimately need more bitrate.
                qualities = [
                  {
                    name = "HDTV-1080p";
                    preferred = 75;
                    max = 90;
                  }
                  {
                    name = "WEBRip-1080p";
                    preferred = 75;
                    max = 90;
                  }
                  {
                    name = "WEBDL-1080p";
                    preferred = 75;
                    max = 90;
                  }
                  {
                    name = "Bluray-1080p";
                    preferred = 75;
                    max = 90;
                  }
                ];
              };

              # Qualities below 1080p are omitted, which disables them.
              quality_profiles = [
                {
                  name = "HD-1080p";
                  quality_sort = "top";
                  min_format_score = 0;
                  upgrade = {
                    allowed = true;
                    until_quality = "Bluray-1080p";
                    until_score = x265Score;
                  };
                  qualities = [
                    { name = "Bluray-1080p"; }
                    {
                      name = "WEB 1080p";
                      qualities = [
                        "WEBRip-1080p"
                        "WEBDL-1080p"
                      ];
                    }
                    { name = "HDTV-1080p"; }
                  ];
                }
              ];

              custom_formats = [
                {
                  # TRaSH "x265 (HD)" custom format.
                  trash_ids = [ "47435ece6b99a0b477caf360e79ba0bb" ];
                  assign_scores_to = [
                    {
                      name = "HD-1080p";
                      score = x265Score;
                    }
                  ];
                }
              ];
            };

            radarr.movies = {
              base_url = "http://127.0.0.1:7878";
              api_key = "!env_var RADARR_API_KEY";
              quality_definition = {
                type = "movie";
                # Cap 1080p at 90 MB/min (~10.8 GB for a 2-hour film).
                # Long or very grainy films legitimately need more bitrate.
                qualities = [
                  {
                    name = "HDTV-1080p";
                    preferred = 75;
                    max = 90;
                  }
                  {
                    name = "WEBRip-1080p";
                    preferred = 75;
                    max = 90;
                  }
                  {
                    name = "WEBDL-1080p";
                    preferred = 75;
                    max = 90;
                  }
                  {
                    name = "Bluray-1080p";
                    preferred = 75;
                    max = 90;
                  }
                ];
              };

              # Qualities below 1080p are omitted, which disables them.
              quality_profiles = [
                {
                  name = "HD-1080p";
                  quality_sort = "top";
                  min_format_score = 0;
                  upgrade = {
                    allowed = true;
                    until_quality = "Bluray-1080p";
                    until_score = x265Score;
                  };
                  qualities = [
                    { name = "Bluray-1080p"; }
                    {
                      name = "WEB 1080p";
                      qualities = [
                        "WEBRip-1080p"
                        "WEBDL-1080p"
                      ];
                    }
                    { name = "HDTV-1080p"; }
                  ];
                }
              ];

              custom_formats = [
                {
                  # TRaSH "x265 (HD)" custom format.
                  trash_ids = [ "dc98083864ea246d05a42df0d05f81cc" ];
                  assign_scores_to = [
                    {
                      name = "HD-1080p";
                      score = x265Score;
                    }
                  ];
                }
              ];
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

      age.secrets.wg-conf = {
        file = ../../secrets/wg-conf.age;
        mode = "0400";
      };

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
