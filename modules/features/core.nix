{config, inputs, ...}: {
  flake.modules.nixos.core = _: {
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

    age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

    system.stateVersion = "26.11";
  };
}
