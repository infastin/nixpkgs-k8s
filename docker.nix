{
  # Core dependencies
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  dockerTools ? pkgs.dockerTools,
  runCommand ? pkgs.runCommand,
  buildPackages ? pkgs.buildPackages,
  # Image configuration
  name ? "nixpkgs",
  tag ? "latest",
  extraPkgs ? [ ],
  maxLayers ? 70,
  uid ? 0,
  gid ? 0,
  uname ? "root",
  gname ? "root",
  Cmd ? [ "${bashInteractive}/bin/bash" ],
  # Default Packages
  bashInteractive ? pkgs.bashInteractive,
  busybox ? pkgs.busybox,
  curl ? pkgs.curl,
  cacert ? pkgs.cacert,
  iana-etc ? pkgs.iana-etc,
  # Other dependencies
  shadow ? pkgs.shadow,
}:
let
  defaultPkgs = [
    bashInteractive
    busybox
    curl
    cacert.out
    iana-etc
  ] ++ extraPkgs;

  users =
    {
      root = {
        uid = 0;
        shell = "${bashInteractive}/bin/bash";
        home = "/root";
        gid = 0;
        groups = [ "root" ];
        description = "System administrator";
      };
      nobody = {
        uid = 65534;
        shell = "${shadow}/bin/nologin";
        home = "/var/empty";
        gid = 65534;
        groups = [ "nobody" ];
        description = "Unprivileged account (don't use!)";
      };
    } // lib.optionalAttrs (uid != 0) {
      "${uname}" = {
        uid = uid;
        shell = "${bashInteractive}/bin/bash";
        home = "/home/${uname}";
        gid = gid;
        groups = [ "${gname}" ];
        description = "Nix user";
      };
    };

  groups =
    {
      root.gid = 0;
      nobody.gid = 65534;
    } // lib.optionalAttrs (gid != 0) {
      "${gname}".gid = gid;
    };

  userToPasswd = (
    k:
    {
      uid,
      gid ? 65534,
      home ? "/var/empty",
      description ? "",
      shell ? "/bin/false",
      groups ? [ ],
    }:
    "${k}:x:${toString uid}:${toString gid}:${description}:${home}:${shell}"
  );
  passwdContents = (lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs userToPasswd users)));

  userToShadow = k: { ... }: "${k}:!:1::::::";
  shadowContents = (lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs userToShadow users)));

  # Map groups to members
  # {
  #   group = [ "user1" "user2" ];
  # }
  groupMemberMap = (
    let
      # Create a flat list of user/group mappings
      mappings = (
        builtins.foldl' (
          acc: user:
          let
            groups = users.${user}.groups or [ ];
          in
          acc
          ++ map (group: {
            inherit user group;
          }) groups
        ) [ ] (lib.attrNames users)
      );
    in
    (builtins.foldl' (
      acc: v:
      acc // {
        ${v.group} = acc.${v.group} or [ ] ++ [ v.user ];
      }
    ) { } mappings)
  );

  groupToGroup =
    k: { gid }:
    let
      members = groupMemberMap.${k} or [ ];
    in
    "${k}:x:${toString gid}:${lib.concatStringsSep "," members}";
  groupContents = (lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs groupToGroup groups)));

  userHome = if uid == 0 then "/root" else "/home/${uname}";

  baseSystem =
    let
      nixpkgs = pkgs.path;
      # doc/manual/source/command-ref/files/manifest.nix.md
      manifest = buildPackages.runCommand "manifest.nix" { } ''
        cat > $out <<EOF
        [
        ${lib.concatStringsSep "\n" (
          builtins.map (
            drv:
            let
              outputs = drv.outputsToInstall or [ "out" ];
            in
            ''
              {
                ${lib.concatStringsSep "\n" (
                  builtins.map (output: ''
                    ${output} = { outPath = "${lib.getOutput output drv}"; };
                  '') outputs
                )}
                outputs = [ ${lib.concatStringsSep " " (builtins.map (x: "\"${x}\"") outputs)} ];
                name = "${drv.name}";
                outPath = "${drv}";
                system = "${drv.system}";
                type = "derivation";
                meta = { };
              }
            ''
          ) defaultPkgs
        )}
        ]
        EOF
      '';
      profile = buildPackages.buildEnv {
        name = "root-profile-env";
        paths = defaultPkgs;
        postBuild = ''
          mv $out/manifest $out/manifest.nix
        '';
        inherit manifest;
      };
    in
    runCommand "base-system"
      {
        inherit
          passwdContents
          groupContents
          shadowContents
          ;
        passAsFile = [
          "passwdContents"
          "groupContents"
          "shadowContents"
        ];
        allowSubstitutes = false;
        preferLocalBuild = true;
      }
      (
        ''
          env
          set -x
          mkdir -p $out/etc

          # may get replaced by pkgs.dockerTools.caCertificates
          mkdir -p $out/etc/ssl/certs
          ln -s /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs

          cat $passwdContentsPath > $out/etc/passwd
          echo "" >> $out/etc/passwd

          cat $groupContentsPath > $out/etc/group
          echo "" >> $out/etc/group

          cat $shadowContentsPath > $out/etc/shadow
          echo "" >> $out/etc/shadow

          mkdir -p $out/usr
          ln -s /nix/var/nix/profiles/share $out/usr/

          mkdir -p $out/nix/var/nix/gcroots

          mkdir $out/tmp

          mkdir -p $out/var/tmp

          mkdir -p $out${userHome}
          mkdir -p $out/nix/var/nix/profiles/per-user/${uname}

          # see doc/manual/source/command-ref/files/profiles.md
          ln -s ${profile} $out/nix/var/nix/profiles/default-1-link
          ln -s /nix/var/nix/profiles/default-1-link $out/nix/var/nix/profiles/default
          ln -s /nix/var/nix/profiles/default $out${userHome}/.nix-profile

          # may get replaced by pkgs.dockerTools.binSh & pkgs.dockerTools.usrBinEnv
          mkdir -p $out/bin $out/usr/bin
          ln -s ${busybox}/bin/env $out/usr/bin/env
          ln -s ${bashInteractive}/bin/bash $out/bin/sh
        ''
      );
in
dockerTools.buildLayeredImageWithNixDb {
  inherit
    name
    tag
    maxLayers
    uid
    gid
    uname
    gname
    ;

  contents = [ baseSystem ];

  extraCommands = ''
    rm -rf nix-support
    ln -s /nix/var/nix/profiles nix/var/nix/gcroots/profiles
  '';
  fakeRootCommands = ''
    chmod 1777 tmp
    chmod 1777 var/tmp
    chown -R ${toString uid}:${toString gid} .${userHome}
    chown -R ${toString uid}:${toString gid} nix
  '';

  config = {
    inherit Cmd;
    User = "${toString uid}:${toString gid}";
    Env = [
      "USER=${uname}"
      "PATH=${
        lib.concatStringsSep ":" [
          "${userHome}/.nix-profile/bin"
          "/nix/var/nix/profiles/default/bin"
          "/nix/var/nix/profiles/default/sbin"
        ]
      }"
      "SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
