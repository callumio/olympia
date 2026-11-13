_:

{
  flake.modules.nixos.ssh = _: {
    services.openssh = {
      enable = true;

      hostKeys = [
        {
            path = "/persist/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
        }
      ];
      openFirewall = true;

      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PubkeyAuthentication = true;

        PermitRootLogin = "no";

        PermitEmptyPasswords = false;
        X11Forwarding = false;
        MaxAuthTries = 3;
      };
    };
  };
}
