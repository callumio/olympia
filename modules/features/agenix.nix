{ inputs, ... }:

{
  flake.modules.nixos.agenix = { config, ... }: {
    imports = [
      inputs.agenix.nixosModules.default
    ];

    age.identityPaths = [
      "${config.olympia.persistencePath}/etc/ssh/ssh_host_ed25519_key"
    ];
  };
}
