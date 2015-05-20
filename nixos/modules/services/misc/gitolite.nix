{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitolite;

  adminPubkey = pkgs.writeText "gitolite-admin.pub" cfg.adminPubkey;

  writeGitoliteConfig = createAndLinkFile ".gitolite/conf/gitolite.conf" cfg.config;
  writeGitoliteRc = createAndLinkFile ".gitolite.rc" cfg.rc;

  writeKeys = user:
    createAndCopyFile ".gitolite/keydir/${user}.pub" (getAttr user cfg.keys);

  writeCommonHooks = name:
    createAndLinkScript ".gitolite/hooks/common/${name}" (getAttr name cfg.hooks.common);

  writeRepoSpecificHooks = name:
    createAndLinkScript ".gitolite/hooks/repo-specific/${name}" (getAttr name cfg.hooks.repoSpecific);

  writeCustomFile = customFile:
    createAndLinkFile customFile.filename customFile.content;

  createGitoliteConfig =
    createAndLinkFile ".gitolite/conf/gitolite.conf" (writeRepos cfg.repos);

  writeRepos = repos:
    concatStringsSep "\n" (map writeRepo (attrNames repos));

  writeRepo = repoName:
    let
      repo = getAttr repoName cfg.repos;
      writeUserSection = users:
        concatStringsSep "\n" (map writeUser (attrNames users));

      writeUser = userName:
        "  ${getAttr userName repo.users} = ${userName}";

    in concatStringsSep "\n" [
      "repo ${repoName}"
      (writeUserSection (repo.users))
      (optionalString (repo.extraConfig != null) "  ${repo.extraConfig}")
      ""
    ];

  createAndLinkScript = path: content:
    let
      filename = legalize (last (splitString "/" path));
      file = pkgs.writeScript filename content;
    in ''
      rm -f ${escapeShellArg path}
      ln -s ${escapeShellArg file} ${escapeShellArg path}
    '';

  createAndLinkFile = path: content:
    let
      filename = legalize (last (splitString "/" path));
      file = pkgs.writeText filename content;
    in ''
      rm -f ${escapeShellArg path}
      ln -s ${escapeShellArg file} ${escapeShellArg path}
    '';

  createAndCopyFile = path: content:
    let
      filename = legalize (last (splitString "/" path));
      file = pkgs.writeText filename content;
    in ''
      rm -f ${escapeShellArg path}
      cp ${escapeShellArg file} ${escapeShellArg path}
    '';

  legalize = filename:
    if (hasPrefix "." filename) then
      removePrefix "." filename
    else
      filename;

in
{
  options = {
    services.gitolite = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable gitolite management under the
          <literal>gitolite</literal> user. After
          switching to a configuration with Gitolite enabled, you can
          then run <literal>git clone
          gitolite@host:gitolite-admin.git</literal> to manage it further.
        '';
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/gitolite";
        description = ''
          Gitolite home directory (used to store all the repositories).
        '';
      };

      adminPubkey = mkOption {
        type = types.nullOr types.str;
        description = ''
          Initial administrative public key for Gitolite. This should
          be an SSH Public Key. Note that this key will only be used
          once, upon the first initialization of the Gitolite user.
          The key string cannot have any line breaks in it.
        '';
      };

      hooks = mkOption {
        type = types.submodule {
          options = {
            common = mkOption {
              type = types.nullOr (types.attrsOf types.str);
              description = ''
                An Attributeset of hooks which get created in <literal>~/.gitolite/hooks/common</literal>.
              '';
              default = null;
            };
            repoSpecific = mkOption {
              type = types.nullOr (types.attrsOf types.str);
              description = ''
                An Attributeset of hooks which get created in <literal>~/.gitolite/hooks/repo-specific</literal>.
              '';
              default = null;
            };
          };
        };
        description = ''
          A list of custom git hooks that get created in <literal>~/.gitolite/hooks/common</literal>.
        '';
        default = {};
      };

      user = mkOption {
        type = types.str;
        default = "gitolite";
        description = ''
          Gitolite user account. This is the username of the gitolite endpoint.
        '';
      };

      mutable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enables configuration of gitolite through nix.
          This disables the gitolite-admin repo and enables config, keys, rc and customFiles.
        '';
      };

      config = mkOption {
        type = types.nullOr types.str;
        description = ''
          Content of gitolite.conf. Overrides the original gitolite.conf if specified!
        '';
        default = null;
      };

      customFiles = mkOption {
        type = types.nullOr (types.listOf (types.submodule {
          options = {
            filename = mkOption {
              type = types.str;
              description = ''
                Location of the custom defined file.
              '';
            };
            content = mkOption {
              type = types.str;
              description = ''
                Content of the custom defined file.
              '';
            };
          };
        }));
        description = ''
          custom files to lay into the configured dataDir. Will override any files which are specified here.
          Use with care!
        '';
        example = ''
          { 
            name = ".gitolite/conf/irc-announce.conf"
            content = 
              #!/bin/sh
              contents of some file
              ...
          }
        '';
        default = null;
      };

      keys = mkOption {
        type = types.attrsOf types.str;
        description = ''
          Ssh-keys which get copied into keydir.
        '';
        example = ''
          { user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM1v/N0G7k48thX1vIALTdqrdYUvYM+SvHRq/rCcKLC2 user@host" };
        '';
        default = {};
      };

      rc = mkOption {
        type = types.nullOr types.str;
        description = ''
          Content of .gitolite.rc. Overrides the original .gitolte.rc if specified!
        '';
        default = null;
      };


      repos = mkOption {
        type = types.nullOr (types.attrsOf (types.submodule {
          options = {
            extraConfig = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                text which gets appended after the user section in gitolite.conf
              '';
            };

            users = mkOption {
              type = types.attrsOf types.str;
              description = ''
                users to configure this gitolite repo for, with usernames as attributeNames and permissions (as strings) as attributes.
              '';
            };
          };
        }));
        description = ''
          Repos to be defined. Will override gitolite.conf if defined.
        '';
        example = {
          config = {
            users = {
              tv = "R";
              lass = "RW+";
            };
            extraConfig = ''
              option hook.post-receive = irc-announce
            '';
          };
        };
        default = null;
      };
    };
  };


  config = mkIf cfg.enable {
  #never define repos and gitolite.conf simultaneaously
  #assert ((cfg.repos == null) || (cfg.repos == null))

    users.extraUsers.${cfg.user} = {
      description     = "Gitolite user";
      home            = cfg.dataDir;
      createHome      = true;
      uid             = config.ids.uids.gitolite;
      useDefaultShell = true;
    };

    systemd.services."gitolite-init" = {
      description = "Gitolite initialization";
      wantedBy    = [ "multi-user.target" ];

      serviceConfig.User = "${cfg.user}";
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;

      path = [ pkgs.gitolite pkgs.git pkgs.perl pkgs.bash pkgs.openssh ];
      script = ''
        cd ${escapeShellArg cfg.dataDir}
        mkdir -p .gitolite/logs

        ${optionalString (cfg.hooks.common != null) ''
          find .gitolite/hooks/common/ -maxdepth 1 -type f -not -name 'update' -delete
          ${(concatStringsSep "\n" (map writeCommonHooks (attrNames cfg.hooks.common)))}
          chmod +x .gitolite/hooks/common/* || :
        ''}
        
        ${optionalString (cfg.hooks.repoSpecific != null) ''
          mkdir -p .gitolite/hooks/repo-specific
          find .gitolite/hooks/repo-specific/ -maxdepth 1 -type f -delete
          ${(concatStringsSep "\n" (map writeRepoSpecificHooks (attrNames cfg.hooks.repoSpecific)))}
          chmod +x .gitolite/hooks/repo-specific/* || :
        ''}

        ${if cfg.mutable then
          optionalString (cfg.adminPubkey != null) ''
            if [ ! -d repositories ]; then
              gitolite setup -pk ${adminPubkey}
            fi
          ''
        else
          concatStrings [
            (optionalString (cfg.keys != {}) ''
              mkdir -p .gitolite/{keydir,conf}
              mkdir -p .gitolite/hooks/{common,repo-specific}
              rm -f .gitolite/keydir/*
              ${concatStringsSep "\n" (map writeKeys (attrNames cfg.keys))}
            '')
            (optionalString (isString cfg.config) writeGitoliteConfig)
            (optionalString (isAttrs cfg.repos) createGitoliteConfig)
            (optionalString (isString cfg.rc) writeGitoliteRc)
            (optionalString (cfg.customFiles != null)
              concatStringsSep "\n" (map writeCustomFile cfg.customFiles)
            )
          ]
        }

        gitolite setup # Upgrade if needed
      '';
    };

    environment.systemPackages = [ pkgs.gitolite pkgs.git ];
  };
}
