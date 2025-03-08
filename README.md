# nixpkgs-k8s

This repository contains Nix flake that produces
images for the most recent three minor releases of kubernetes
with the following packages:

- xz
- busybox
- kubectl
- curl
- awscli2
- jq
- yq-go
- gettext
- gomplate
- nushell

This repository was created to provide a container
with basic utilities, for running inside kubernetes jobs.
