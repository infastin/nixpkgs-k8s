{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      kubectlVersion = "1.31.2";
    in
    {
      overlays = {
        default = final: prev: {
          kubectl = prev.kubectl.overrideAttrs (oldAttrs: {
            version = kubectlVersion;
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${kubectlVersion}";
              hash = "sha256-L+x1a9wttu2OBY5T6AY8k91ystu0uZAGd3px4oNVptM=";
            };
          });
        };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          overlays = [
            self.overlays.default
          ];
        };

      in {
        packages.container = let
          tmpDir = pkgs.runCommand "tmp" { } ''
            mkdir $out
            mkdir -m 1777 $out/tmp
          '';
        in
        pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/infastin/nixpkgs-k8s";
          tag = "latest";
          created = "now";
          contents = with pkgs; [
            tmpDir
            dockerTools.usrBinEnv
            dockerTools.binSh
            dockerTools.caCertificates
            dockerTools.fakeNss
            busybox
            kubectl
            curl
            awscli2
          ];
          config = {
            Cmd = [ "${pkgs.dockerTools.binSh}/bin/sh" ];
          };
        };
      });
}
