_:

{
  flake.modules.nixos.ssh = _: {
    services.openssh = {
      enable = true;

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
