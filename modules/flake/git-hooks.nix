{ inputs, ... }: {
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { config, ... }:
    {
      pre-commit.settings.hooks.treefmt = {
        enable = true;
        package = config.treefmt.build.wrapper;
      };

      devShells.default = config.pre-commit.devShell;
    };
}
