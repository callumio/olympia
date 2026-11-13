_:

{
  flake.modules.nixos.zfs = _: {
    boot.supportedFilesystems = [ "zfs" ];

    services.zfs = {
      autoScrub.enable = true;
    };
  };
}
