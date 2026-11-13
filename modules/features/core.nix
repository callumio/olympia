{config, inputs, ...}: {
  flake.modules.nixos.core = _: {
    imports = [inputs.agenix.nixosModules.default];
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

    # age.rekey = {
    #     localStorageDir = inputs.self + "/secrets/${config.networking.hostName}";
    #     masterIdentities = [ ../../secrets/master.pub ];
    #     storageMode = "local";
    # };
    age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
  };
}
