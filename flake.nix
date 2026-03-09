{
  description = "Local HTTP proxy providing gcloud access tokens over a Unix socket";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    purse-first.url = "github:amarbel-llc/purse-first";
  };

  outputs =
    { nixpkgs, purse-first, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
    in
    {
      packages = forAllSystems (
        pkgs: _system: {
          default = pkgs.writeShellApplication {
            name = "gcloud-auth-proxy";
            runtimeInputs = with pkgs; [
              socat
              curl
              google-cloud-sdk
            ];
            text = builtins.readFile ./bin/gcloud-auth-proxy;
          };
        }
      );

      devShells = forAllSystems (
        pkgs: system: {
          default = pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.gum
              pkgs.curl
              pkgs.socat
              purse-first.packages.${system}.batman
            ];
          };
        }
      );
    };
}
