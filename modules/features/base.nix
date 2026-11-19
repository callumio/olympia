{ config, ... }:

{
  flake.modules.nixos.base = {
    imports = [
      config.flake.modules.nixos.options
      config.flake.modules.nixos.agenix
      config.flake.modules.nixos.deploy
      config.flake.modules.nixos.admins
      config.flake.modules.nixos.storage-options
      config.flake.modules.nixos.storage-disko
    ];
  };
}
