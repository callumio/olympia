let
  heimdall = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtgoFYu7sDOFrfxxTY8j0dKVIqFlLmwjTt19WLxRmLf root@heimdall";
  atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIINlwdKxZPFcpb8Q+FklsvqjgVbuFwCY48DuemuWmRu3 root@atlas";
  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW89GwFXo01iKQKY6NVRTN61/1SIoYhN3sAo18hLY17 ssh@cleslie.uk";
in
{
  "heimdall-admin-pw.age".publicKeys = [
    heimdall
    admin
  ];
  "atlas-admin-pw.age".publicKeys = [
    atlas
    admin
  ];
  "tailscale-auth-bootstrap-key.age".publicKeys = [
    atlas
    heimdall
    admin
  ];
  "zeroclaw-env.age".publicKeys = [
    heimdall
    admin
  ];
}
