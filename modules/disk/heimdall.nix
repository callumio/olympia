_:

{
  flake.modules.nixos.disk-heimdall = {
    disko.devices = {
      disk.main = {
        type = "disk";
        device = "/dev/sda";

        content = {
          type = "gpt";

          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";

              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
              };
            };

            root = {
              size = "100%";

              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
