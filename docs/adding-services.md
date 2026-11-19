# Adding a New Service

This repo uses a small, consistent pattern:

- A **feature module** lives under `modules/` and registers itself as `flake.modules.nixos.<name>`.
- A **host module** under `modules/hosts/` imports the feature modules it wants.
- The host module is an ordinary NixOS module. It uses native NixOS options plus `olympia.*` options for repo-specific data.
- `modules/infrastructure/nixos.nix` only maps `hosts.<name>` to `nixosConfigurations`. It does not translate feature settings.

There is no `mySystem` namespace. Use native options (`services.foo`, `networking.*`, `users.*`, etc.). If you need an option that NixOS does not provide, put it under `olympia.*` in the module that owns the concept.

---

## 1. Create the feature module

Create a file under `modules/services/` or `modules/features/`. Any `.nix` file under `modules/` is imported automatically by `import-tree`, so no registration list is needed.

Minimal module:

```nix
# modules/services/myservice.nix
_:

{
  flake.modules.nixos.myservice = { config, lib, ... }: {
    services.myservice = {
      enable = true;
    };
  };
}
```

If the service needs repo-specific options, declare them in the same module:

```nix
# modules/services/myservice.nix
_:

{
  flake.modules.nixos.myservice = { config, lib, ... }: let
    cfg = config.olympia.myservice;
  in {
    options.olympia.myservice = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for myservice.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
      };
    };

    config = {
      services.myservice = {
        enable = true;
        address = "127.0.0.1";
        port = cfg.port;
      };
    };
  };
}
```

Guidelines:

- Use `lib.mkDefault` for values a host may want to override.
- Use `lib.mkIf` for conditional config.
- Do not add a global namespace like `mySystem`. Keep feature options with the feature.
- `base` is imported by every host, so `age.secrets`, `olympia.persistencePath`, and `olympia.secretsDir` are available to feature modules. `environment.persistence` is only available if the host imports `modules.impermanent`; guard it if the module may run on a non-impermanent host.

---

## 2. Add the module to a host

Hosts live in `modules/hosts/<name>.nix`. A host is a flake-parts module that sets `hosts.<name>` with only two fields:

- `system`
- `module` (a NixOS module)

Example host:

```nix
{ config, ... }:

let
  modules = config.flake.modules.nixos;
in
{
  hosts.heimdall = {
    system = "aarch64-linux";

    module = { config, ... }: {
      imports = [
        modules.base
        modules.core
        modules.ssh
        modules.myservice
        # ...
      ];

      olympia.myservice.host = "service.example.com";
    };
  };
}
```

`nixos.nix` sets `networking.hostName` from the `hosts.<name>` attribute name, so do not set it in the host module unless you intentionally want a different hostname.

If a service should be part of every host, add it to `modules/features/base.nix` instead of importing it host-by-host. Be careful: `base` is the shared plumbing module, so only put genuinely universal modules there.

### Adding a new host

Create `modules/hosts/<name>.nix`:

```nix
{ config, ... }:

let
  modules = config.flake.modules.nixos;
in
{
  hosts.<name> = {
    system = "x86_64-linux";

    module = {
      imports = [
        modules.base
        modules.core
        modules.ssh
        # ...
      ];

      networking.hostId = "........";
      time.timeZone = "Europe/London";

      olympia.deploy = {
        enable = true;
        hostname = "<name>";
        publicKeys = [ ];
      };
    };
  };
}
```

No central list needs updating; `import-tree` picks up the new file.

---

## 3. Expose it through Caddy (optional)

Caddy is enabled by importing `modules.caddy`. The caddy module itself only does two things:

```nix
services.caddy.enable = true;
networking.firewall.allowedTCPPorts = [ 80 443 ];
```

It does **not** configure virtual hosts. Add those with the native NixOS option:

```nix
services.caddy.virtualHosts."service.example.com".extraConfig = ''
  reverse_proxy 127.0.0.1:8080
'';
```

Prefer using the service's own address/port options instead of repeating literals:

```nix
services.caddy.virtualHosts.${cfg.host}.extraConfig = ''
  reverse_proxy ${config.services.myservice.address}:${toString config.services.myservice.port}
'';
```

### Where to put the Caddy config

There are two clean patterns.

**Pattern A — host owns the vhost.** The host imports both the service and Caddy:

```nix
imports = [
  modules.base
  modules.myservice
  modules.caddy
];

services.caddy.virtualHosts."service.example.com".extraConfig = ''
  reverse_proxy 127.0.0.1:8080
'';
```

This is the simplest option when the service is only used on one host.

**Pattern B — service module owns the vhost.** The service imports Caddy itself and configures the vhost from its own options. This is what `modules/features/mesh.nix` does for Headscale:

```nix
{ config, ... }:

let
  caddyModule = config.flake.modules.nixos.caddy;
in
{
  flake.modules.nixos.myservice = { config, lib, ... }: let
    cfg = config.olympia.myservice;
  in {
    imports = [ caddyModule ];

    options.olympia.myservice = {
      host = lib.mkOption { type = lib.types.str; };
    };

    config = {
      services.myservice = {
        enable = true;
        address = "127.0.0.1";
        port = 8080;
      };

      services.caddy.virtualHosts.${cfg.host}.extraConfig = ''
        reverse_proxy ${config.services.myservice.address}:${toString config.services.myservice.port}
      '';
    };
  };
}
```

This keeps the service self-contained and reusable.

### Caddy notes

- Caddy handles TLS automatically. Point DNS at the host and make sure ports 80/443 are reachable.
- If the service is behind Caddy, bind it to `127.0.0.1` and do not open its port in the firewall.
- If the service is exposed directly, add `networking.firewall.allowedTCPPorts = [ ... ];` instead.
- Use one vhost key per hostname. Multiple modules can add different hostnames safely, but two modules should not both write `extraConfig` for the same hostname.
- For internal-only services, skip Caddy and expose them over Tailscale/Headscale instead.
- `services.caddy.email` is not set by the caddy module. Set it in the host module if you want ACME account emails.

---

## 4. Persist state

On impermanent hosts, state outside `/persist` is rolled back on boot. Add the service's state directory to the impermanence config:

```nix
environment.persistence.${config.olympia.persistencePath}.directories = [
  "/var/lib/myservice"
];
```

If the module may also be used on a host that does not import `modules.impermanent`, guard the assignment:

```nix
config = {
  services.myservice.enable = true;
} // lib.optionalAttrs (options.environment ? persistence) {
  environment.persistence.${config.olympia.persistencePath}.directories = [
    "/var/lib/myservice"
  ];
};
```

Use `options.environment ? persistence`, not `config.environment ? persistence`. Checking `config` while building config can cause infinite recursion.

`olympia.persistencePath` defaults to `/persist` and is defined in `modules/infrastructure/options.nix`.

---

## 5. Add a secret

Secrets use agenix. `base` imports the agenix module, so `age.secrets` is available in every host.

1. Add the secret to `secrets/secrets.nix`:

```nix
{
  "myservice-env.age".publicKeys = [
    heimdall
    admin
  ];
}
```

2. Create the encrypted file:

```sh
agenix -e secrets/myservice-env.age
```

3. Reference it from the module or host:

```nix
age.secrets.myservice-env = {
  file = ../../secrets/myservice-env.age;
};

services.myservice.environmentFile = config.age.secrets.myservice-env.path;
```

The agenix identity path is derived from `olympia.persistencePath`:

```nix
age.identityPaths = [
  "${config.olympia.persistencePath}/etc/ssh/ssh_host_ed25519_key"
];
```

For a user password, `olympia.admins.<name>.passwordFile` already wires up `age.secrets` and `hashedPasswordFile`. Use that instead of setting `hashedPasswordFile` manually.

---

## 6. Full worked example: Vaultwarden

Module:

```nix
# modules/services/vaultwarden.nix
{ config, ... }:

let
  caddyModule = config.flake.modules.nixos.caddy;
in
{
  flake.modules.nixos.vaultwarden =
    { config, lib, options, ... }:
    let
      cfg = config.olympia.vaultwarden;
    in
    {
      imports = [ caddyModule ];

      options.olympia.vaultwarden = {
        host = lib.mkOption {
          type = lib.types.str;
          description = "Public hostname for Vaultwarden.";
        };
      };

      config = {
        age.secrets.vaultwarden-env = {
          file = ../../secrets/vaultwarden-env.age;
        };

        services.vaultwarden = {
          enable = true;
          environmentFile = config.age.secrets.vaultwarden-env.path;

          config = {
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = 8222;
            DOMAIN = "https://${cfg.host}";
            SIGNUPS_ALLOWED = false;
          };
        };

        services.caddy.virtualHosts.${cfg.host}.extraConfig = ''
          reverse_proxy 127.0.0.1:8222
        '';
      }
      // lib.optionalAttrs (options.environment ? persistence) {
        environment.persistence.${config.olympia.persistencePath}.directories = [
          "/var/lib/vaultwarden"
        ];
      };
    };
}
```

Host:

```nix
imports = [
  modules.base
  modules.core
  modules.ssh
  modules.vaultwarden
  # ...
];

olympia.vaultwarden.host = "vault.example.com";
```

This gives you:

- Vaultwarden enabled and bound to localhost.
- Caddy enabled (via the module import) with a reverse proxy vhost.
- The environment file loaded from agenix.
- `/var/lib/vaultwarden` persisted on impermanent hosts.
- No manual firewall changes, because Caddy owns ports 80/443.

---

## 7. Verify

```sh
nix fmt

# Does the module evaluate?
nix eval .#nixosConfigurations.heimdall.config.services.myservice.enable

# Does the whole host evaluate?
nix eval .#nixosConfigurations.heimdall.config.system.build.toplevel.drvPath

# Evaluate all flake outputs
nix flake check --no-build

# Build the host without switching
nixos-rebuild build --flake .#heimdall
```

Notes:

- New files must be tracked by git before flake evaluation. If you just created a module and `nix eval` says the flake module is missing, run `git add <file>` first.
- `nix flake check` checks the current system by default. For the `aarch64-linux` host, evaluate it directly or use `nix flake check --all-systems`.
- If the host uses a new secret, the `.age` file must exist before building.

---

## 8. Checklist

- [ ] Module created under `modules/`, registered as `flake.modules.nixos.<name>`.
- [ ] Native NixOS options used; repo-specific options under `olympia.*`.
- [ ] Defaults use `lib.mkDefault` where hosts may override.
- [ ] Module imported by the intended host(s).
- [ ] Caddy vhost added if the service is public.
- [ ] Service binds to `127.0.0.1` when behind Caddy.
- [ ] State directory added to `environment.persistence` if the host is impermanent.
- [ ] Secret added to `secrets/secrets.nix` and encrypted with `agenix`.
- [ ] `nix fmt`, `nix flake check --no-build`, and a host build all pass.
