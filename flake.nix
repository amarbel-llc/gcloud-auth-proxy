{
  description = "Local HTTP proxy providing gcloud access tokens over a Unix socket";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellApplication {
          name = "gcloud-auth-proxy";
          runtimeInputs = with pkgs; [
            socat
            curl
            google-cloud-sdk
          ];
          text = builtins.readFile ./bin/gcloud-auth-proxy;
        };
      });
    };
}
