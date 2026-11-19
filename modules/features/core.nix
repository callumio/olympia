{ lib, ... }: {
  flake.modules.nixos.core = { pkgs, ... }: {
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "@wheel"
        ];
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
    };

    environment.systemPackages = with pkgs; [
      vim
      git
    ];

    users.mutableUsers = lib.mkDefault false;

    system.stateVersion = lib.mkDefault "26.11";
  };
}
