_:

{
  flake.modules.nixos.nfs =
    {
      pkgs,
      ...
    }:
    {
      # NFSv4 pseudo-root. The client sees /media and /cloud; the bind mounts
      # keep the public export tree separate from /tank/backup.
      fileSystems."/srv/nfs/media" = {
        device = "/tank/media";
        fsType = "none";
        options = [ "bind" ];
        depends = [ "/tank/media" ];
      };

      fileSystems."/srv/nfs/cloud" = {
        device = "/tank/cloud";
        fsType = "none";
        options = [ "bind" ];
        depends = [ "/tank/cloud" ];
      };

      fileSystems."/srv/nfs/photos" = {
        device = "/tank/photos";
        fsType = "none";
        options = [ "bind" ];
        depends = [ "/tank/photos" ];
      };

      services.nfs.server = {
        enable = true;
        createMountPoints = true;

        exports = {
          "/srv/nfs" = {
            "100.64.0.0/10" = [
              "ro"
              "fsid=0"
              "crossmnt"
              "no_subtree_check"
            ];
          };

          "/srv/nfs/media" = {
            "100.64.0.0/10" = [
              "ro"
              "nohide"
              "no_subtree_check"
            ];
          };

          "/srv/nfs/cloud" = {
            "100.64.0.0/10" = [
              "rw"
              "nohide"
              "no_subtree_check"
              "all_squash"
              "anonuid=1000"
              "anongid=1000"
            ];
          };

          "/srv/nfs/photos" = {
            "100.64.0.0/10" = [
              "rw"
              "nohide"
              "no_subtree_check"
              "all_squash"
              "anonuid=1000"
              "anongid=1000"
            ];
          };
        };
      };

      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 2049 ];

      # all_squash maps Hermes' writes to UID/GID 1000, so the datasets must
      # be writable by that user.
      systemd.services.nfs-data-ownership = {
        description = "Set ownership on the NFS data datasets";
        wantedBy = [ "multi-user.target" ];
        before = [ "nfs-server.service" ];
        unitConfig.RequiresMountsFor = [
          "/tank/cloud"
          "/tank/photos"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.coreutils}/bin/chown 1000:1000 /tank/cloud /tank/photos
        '';
      };
    };
}
