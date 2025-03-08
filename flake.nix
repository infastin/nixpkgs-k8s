{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlays = {
        default = final: prev: {
          kubectl_1_30_10 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.30.10";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-Zy2IoHyOLx1A2lr0o+DmjdhLIPQ4ePdT/+HeXwC2pTw=";
            };
          });

          kubectl_1_31_6 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.31.6";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-WWw2rzhChICTsUlm3OmcxP/oZdhuiziPg/YJfNb0hJA=";
            };
          });

          kubectl_1_32_2 = prev.kubectl.overrideAttrs (oldAttrs: rec {
            version = "1.32.2";
            src = prev.fetchFromGitHub {
              owner = "kubernetes";
              repo = "kubernetes";
              rev = "v${version}";
              hash = "sha256-pie36Y3zKGKvnCDHtjNHYox1b2xhy6w7MShkAfkDVrs=";
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
                  gomplate
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
            first = buildImage { kubectl = pkgs.kubectl_1_30_10; };
            second = buildImage { kubectl = pkgs.kubectl_1_31_6; };
            third = buildImage { kubectl = pkgs.kubectl_1_32_2; };
          };
      });
}
