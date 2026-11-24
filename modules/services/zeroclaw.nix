{ inputs, ... }:
let
  zeroclawModule = inputs.zeroclaw.nixosModules.default;
in
{
  flake.modules.nixos.zeroclaw =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.olympia.zeroclaw;
      # zeroclawPackage = inputs.zeroclaw.packages.${pkgs.stdenv.hostPlatform.system}.zeroclaw;
      zeroclawPackage = inputs.zeroclaw.packages.aarch64-linux.zeroclaw.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [
          pkgs.aws-lc
          pkgs.sqlite
        ];
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
        env = (old.env or { }) // {
          CARGO_PROFILE_RELEASE_LTO = "off";
          CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
        };
      });
      dataDir = "/var/lib/zeroclaw-${cfg.name}";
      instanceUser = "zeroclaw-${cfg.name}";
    in
    {
      imports = [ zeroclawModule ];

      options.olympia.zeroclaw = {
        enable = lib.mkEnableOption "ZeroClaw";

        name = lib.mkOption {
          type = lib.types.str;
          default = "main";
          description = "ZeroClaw instance name. Also used for the systemd unit, user, and state directory.";
        };

        model = lib.mkOption {
          type = lib.types.str;
          default = "deepseek-v4.1-flash";
          description = "OpenCode Go model ID.";
        };

        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://opencode.ai/inference/go/openai/v1";
          description = "OpenCode Go OpenAI-compatible base URL.";
        };

        telegram = {
          alias = lib.mkOption {
            type = lib.types.str;
            default = "main";
            description = "Telegram channel alias.";
          };

          allowedUsers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Telegram numeric user IDs or usernames allowed to talk to the
              agent. Leave empty to use the one-time /bind pairing code.
            '';
          };

          mentionOnly = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Only answer group messages that @-mention or directly reply to the bot. Direct messages are always processed.";
          };

          passiveGroupContext = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Record unaddressed group messages from authorized members as
              passive conversation context, without replying to them.
              Requires {option}`mentionOnly`.
            '';
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          assertions = lib.optional (cfg.telegram.passiveGroupContext && !cfg.telegram.mentionOnly) {
            assertion = false;
            message = "olympia.zeroclaw.telegram.passiveGroupContext requires olympia.zeroclaw.telegram.mentionOnly = true.";
          };

          age.secrets.zeroclaw-env = {
            file = ../../secrets/zeroclaw-env.age;
          };

          services.zeroclaw.instances.${cfg.name} = {
            package = zeroclawPackage;
            environmentFile = config.age.secrets.zeroclaw-env.path;

            settings = {
              schema_version = 4;

              providers.models.opencode.go = {
                inherit (cfg) model;
                uri = cfg.baseUrl;
                api_key = "$OPENCODE_API_KEY";

                # OpenCode Go asks clients to identify themselves with their
                # own user agent rather than a generic HTTP-library one.
                # ZeroClaw derives x-opencode-session per conversation itself.
                extra_headers."User-Agent" = "zeroclaw/${lib.getVersion zeroclawPackage}";
              };

              agents.assistant = {
                model_provider = "opencode.go";
                risk_profile = "assistant";
                channels = [ "telegram.${cfg.telegram.alias}" ];
              };

              risk_profiles.assistant = { };

              channels.telegram.${cfg.telegram.alias} = {
                enabled = true;
                bot_token = "$TELEGRAM_BOT_TOKEN";
                mention_only = cfg.telegram.mentionOnly;
                passive_group_context = cfg.telegram.passiveGroupContext;
              };

              peer_groups."telegram_${cfg.telegram.alias}" = {
                channel = "telegram.${cfg.telegram.alias}";
                agents = [ "assistant" ];
                external_peers = cfg.telegram.allowedUsers;
              };
            };
          };
        })
        (lib.mkIf (cfg.enable && (options.environment ? persistence)) {
          environment.persistence.${config.olympia.persistencePath}.directories = [
            {
              directory = dataDir;
              user = instanceUser;
              group = instanceUser;
              mode = "0750";
            }
          ];

          # Impermanence bind-mounts /persist/... over dataDir, and an existing
          # source directory keeps its root ownership. The upstream module's
          # tmpfiles rule runs before that mount, so repair ownership here.
          system.activationScripts.zeroclaw-data-dir = {
            deps = [
              "createPersistentStorageDirs"
              "users"
              "groups"
            ];
            text = ''
              ${pkgs.coreutils}/bin/install -d -o ${lib.escapeShellArg instanceUser} -g ${lib.escapeShellArg instanceUser} -m 0750 ${lib.escapeShellArg dataDir}
            '';
          };
        })
      ];
    };
}
