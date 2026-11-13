_: {
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

    system.stateVersion = "26.11";

    age.rekey = {
        localStorageDir = ../../. + "/secrets/${config.networking.hostName}";
        masterIdentities = [ ../../secrets/master.pub ];
        storageMode = "local";
    };
  };
}
