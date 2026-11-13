let 
heimdall = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtgoFYu7sDOFrfxxTY8j0dKVIqFlLmwjTt19WLxRmLf root@heimdall";
admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk";
in {
    "heimdall-admin-pw.age".publicKeys = [ heimdall admin ];
    "heimdall-tailscale-auth-key.age".publicKeys = [ heimdall admin ];
}

