{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlays = {
        default = final: prev: {
          kubectl_1_31_10 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.31.10";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-renFznJJLYvfIJn59yx9BeZ5HRtSIdtDXXIK2CEs4MU=";
            };
          });

          kubectl_1_32_6 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.32.6";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-MCKYcum4rib7qzKyZ7YMMYYhSPqNF5a/D33d9REa8Eo=";
            };
          });

          kubectl_1_33_2 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.33.2";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-Ef/tpjM5RGQzO8rZxTad23DuM6VLlV3N54LOu7dtc6A=";
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
        packages =
          let
            buildImage = { kubectl }:
              pkgs.dockerTools.buildLayeredImage {
                name = "ghcr.io/infastin/nixpkgs-k8s";
                tag = kubectl.version;
                created = "now";

                contents = with pkgs; [
                  dockerTools.usrBinEnv
                  dockerTools.binSh
                  dockerTools.caCertificates
                  bashInteractive
                  xz
                  busybox
                  curl
                  awscli2
                  jq
                  yq-go
                  gettext
                ] ++ [
                  kubectl
                ];

                fakeRootCommands = ''
                  ${pkgs.dockerTools.shadowSetup}
                  mkdir -m 0500 /root
                  mkdir -p /var
                  mkdir -m 1777 /tmp /var/tmp
                '';
                enableFakechroot = true;

                config = {
                  Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
                };
              };
          in {
            first = buildImage { kubectl = pkgs.kubectl_1_31_10; };
            second = buildImage { kubectl = pkgs.kubectl_1_32_6; };
            third = buildImage { kubectl = pkgs.kubectl_1_33_2; };
          };
      });
}
