_: {
  flake.modules.nixos.oracle-ampere = { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

    nixpkgs.hostPlatform = "aarch64-linux";

    boot.initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "xen_blkfront"
    ];
    boot.initrd.kernelModules = [ "nvme" ];

    boot.tmp.cleanOnBoot = true;
    boot.loader = {
  efi = {
    canTouchEfiVariables = false;
    efiSysMountPoint = "/boot";
  };

  grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = [ "nodev" ];
  };
};
  };
}
