{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      kubernetesVersion = "1.32.2";
    in
    {
      overlays = {
        default = final: prev: {
          kubectl = prev.kubectl.overrideAttrs (oldAttrs: {
            version = kubernetesVersion;
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${kubernetesVersion}";
              hash = "sha256-pie36Y3zKGKvnCDHtjNHYox1b2xhy6w7MShkAfkDVrs=";
            };
          });

          tmpDir = prev.runCommand "tmp" { } ''
            mkdir $out
            mkdir -m 1777 $out/tmp
          '';
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
        packages.default = pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/infastin/nixpkgs-k8s";
          tag = kubernetesVersion;
          created = "now";
          contents = with pkgs; [
            tmpDir
            dockerTools.usrBinEnv
            dockerTools.binSh
            dockerTools.caCertificates
            busybox
            kubectl
            curl
            awscli2
          ];
          fakeRootCommands = ''
            ${pkgs.dockerTools.shadowSetup}
            mkdir -p /root
            chmod 0550 /root
          '';
          enableFakechroot = true;
          config = {
            Cmd = [ "${pkgs.dockerTools.binSh}/bin/sh" ];
          };
        };
      });
}
