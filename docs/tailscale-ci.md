# Keyless CI Deployment over Tailscale

CI deploys with deploy-rs over Tailscale SSH. There are no SSH keys in CI:
GitHub Actions proves its identity to hetm, hetm mints an ephemeral
`tag:ci` pre-auth key, the runner joins the tailnet, and deploy-rs connects
to the target's tailnet name where `tailscaled --ssh` serves port 22.

## How it fits together

1. GitHub Actions requests an OIDC token with audience `hetm.cleslie.uk`.
2. The runner sends that token to `https://hetm.cleslie.uk/token`.
3. hetm verifies the token against the configured `allow` patterns and asks
   Headscale for an ephemeral, tags-only pre-auth key.
4. The runner runs `tailscale up` with that key and becomes a `tag:ci` node.
5. deploy-rs runs plain OpenSSH against the target's MagicDNS name.
   The target's `tailscaled` has claimed port 22 on its tailnet address, so
   Tailscale authorizes the connection using the `ssh` rules in the ACL
   policy instead of `authorized_keys`.

No private keys are stored in CI, and the pre-auth key expires after hetm's
TTL (five minutes by default).

## Policy

The ACL policy lives in `modules/features/headscale-policy.json` and is
installed at `/etc/headscale/policy.hujson` by `modules/features/mesh.nix`.
Headscale reads that stable path. The module also sets a `reloadTriggers`
entry and an `ExecReload` that sends `SIGHUP`, so `nixos-rebuild switch`
reloads the policy in place instead of restarting Headscale. To reload a
policy that was edited on the host:

```sh
sudo systemctl reload headscale
```

The policy uses ownerless tags. Headscale only requires the tag key to exist;
a node gets the tag from a tagged pre-auth key or from `headscale nodes tag`,
not by assigning an owner.

- `tag:ci` may reach `tag:server` on TCP 22, and may use Tailscale SSH as
  `deploy`.
- `autogroup:member` keeps normal admin access to the tailnet and may use
  Tailscale SSH as `root` or `deploy` on servers.
- Every other `tag:ci` connection is denied.

The `ssh` section is required. A packet ACL that allows port 22 is not enough
for Tailscale SSH; tailscaled denies the connection unless an `ssh` rule also
matches.

## Tag the deploy target

A host only accepts CI deploys after it has the `tag:server` tag. Tag it once
from the Headscale host:

```sh
sudo headscale nodes list
sudo headscale nodes tag -i <node-id> -t tag:server
```

Use the node ID from the first command. Re-tag any new deploy target the same
way. CI nodes do not need manual tagging: hetm's keys already carry `tag:ci`.

## Host configuration

A deploy target needs Tailscale SSH, a stable tailnet name, and SSH options
that do not prompt in CI. `modules/hosts/heimdall.nix` is the reference:

```nix
olympia.tailscale = {
  authKeyFile = ../../secrets/tailscale-auth-bootstrap-key.age;
  loginServer = "https://${config.olympia.headscale.host}";
  acceptDns = false;
  ssh = true;
};

olympia.deploy = {
  enable = true;
  hostname = "heimdall.net.cleslie.uk";
  publicKeys = [ ];
  sshOpts = [ "-o" "StrictHostKeyChecking=accept-new" ];
};
```

`olympia.tailscale.ssh` adds `--ssh` to `tailscale up`. NixOS only applies
`extraUpFlags` when `authKeyFile` is set, so that option requires an auth key.
On a node that is already logged in, `tailscaled-autoconnect` sees the
`Running` state and does not run `tailscale up` again. After the first switch
that enables this option, run it once by hand:

```sh
sudo tailscale up --ssh
```

Tailscale stores that preference in `/var/lib/tailscale`, which is persisted
on these hosts, so it survives reboots.

`olympia.deploy.sshOpts` is passed straight to deploy-rs. The target uses its
MagicDNS name so the connection lands on the tailnet address, not a public IP.

## CI workflow

The deployment job needs `id-token: write` so GitHub can issue the OIDC token,
and it needs Tailscale available on the runner:

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get Tailscale pre-auth key
        id: tailscale
        run: |
          token=$(curl -fsS \
            -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=hetm.cleslie.uk" \
            | jq -r .value)

          key=$(curl -fsS \
            -H "Authorization: Bearer $token" \
            -X POST https://hetm.cleslie.uk/token \
            | jq -r .key)

          echo "::add-mask::$key"
          echo "key=$key" >> "$GITHUB_OUTPUT"

      - name: Join tailnet
        uses: tailscale/github-action@v3
        with:
          authkey: ${{ steps.tailscale.outputs.key }}
          args: --hostname=gh-${{ github.run_id }}

      - name: Deploy
        run: nix run github:serokell/deploy-rs -- .#heimdall
```

Adjust the attribute (`.#heimdall`) to the host being deployed. If the runner
does not already have Nix, add `cachix/install-nix-action` before the deploy
step.

## Security notes

- `tag:ci` can log in as `deploy`, and `deploy` has passwordless sudo for
  `ALL`. Treat a CI pre-auth key as root on every `tag:server` host.
- Keys are ephemeral and short-lived, but the GitHub workflow that can mint
  them is effectively a deployment credential. Protect the workflow and its
  `allow` patterns.
- Ownerless tags mean users cannot self-assign `tag:ci` or `tag:server`.
  Only tagged pre-auth keys and explicit `headscale nodes tag` can do it.

## Verify

```sh
nix fmt
nix eval .#nixosConfigurations.heimdall.config.system.build.toplevel.drvPath
nix eval .#deploy.nodes.heimdall.profiles.system.sshOpts
nix flake check --no-build
```
