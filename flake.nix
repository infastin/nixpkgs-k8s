{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlays = {
        default = final: prev: {
          kubectl_1_31_11 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.31.11";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-w4pVk2J7LuU2jbyklmOZSUrB1AwIzusQgxp89OdtK1I=";
            };
          });

          kubectl_1_32_7 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.32.7";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-64002KyKgITobf4WCVgA1TQwJmnIG9rVUuuq8wPYKn4=";
            };
          });

          kubectl_1_33_3 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.33.3";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-UZdrfQEEx0RRe4Bb4EAWcjgCCLq4CJL06HIriYuk1Io=";
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
            mkImage = attrs:
              pkgs.callPackage ./docker.nix (attrs // {
                Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
              });

            buildImage = { kubectl }:
              pkgs.dockerTools.buildImage {
                name = "ghcr.io/infastin/nixpkgs-k8s";
                tag = kubectl.version;
                created = "now";

                fromImage = mkImage {
                  extraPkgs = with pkgs; [
                    xz
                    awscli2
                    jq
                    yq-go
                    gettext
                  ] ++ [
                    kubectl
                  ];
                };

                config = {
                  Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
                  User = "0:0";
                };
              };
          in {
            first = buildImage { kubectl = pkgs.kubectl_1_31_11; };
            second = buildImage { kubectl = pkgs.kubectl_1_32_7; };
            third = buildImage { kubectl = pkgs.kubectl_1_33_3; };
          };
      });
}
