{
  inputs,
  ...
}:

{
  flake.modules.nixos.nixarr =
    { config, ... }:
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
