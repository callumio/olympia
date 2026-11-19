{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      apps.deploy = {
        type = "app";
        program = "${inputs.deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
        meta.description = "Deploy a host with deploy-rs";
      };
    };
}
