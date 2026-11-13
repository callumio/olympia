let 
heimdall = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1mGywKQUgOpxOC5Df8Si5FXdZEDc726Fx21Z0n3cY2 root@heimdall";
admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk";
in {
    "heimdall-admin-pw.age".publicKeys = [ heimdall admin ];
}

