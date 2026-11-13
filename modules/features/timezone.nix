{ lib, ... }:

{
  flake.modules.nixos.timezone = _: {
    time.hardwareClockInLocalTime = lib.mkDefault false;
  };
}
