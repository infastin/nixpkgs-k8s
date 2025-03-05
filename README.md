# nixpkgs-k8s

This repository contains Nix flake that produces
a container with the following packages:

- xz
- busybox
- kubectl
- curl
- awscli2
- jq
- yq-go
- gettext
- gomplate

This repository was created to provide a container
with basic utilities, for running inside kubernetes jobs.
