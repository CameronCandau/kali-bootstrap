{ inputs, ... }:
{
  flake.homeModules.kaliHome = { config, lib, pkgs, ... }:
  let
    homeDir = config.home.homeDirectory;
    oscpRoot = "${homeDir}/oscp";
    payloadRoot = "${homeDir}/tools/payloads";
    artifactLockerRoot = "${homeDir}/.local/share/artifact-locker";
  in
  {
    imports = [
      inputs.dotfiles.homeModules.core
      inputs.dotfiles.homeModules.x11Userland
      inputs.dotfiles.homeModules.desktopI3
      inputs.dotfiles.homeModules.classicI3
    ];

    home.username = "kali";
    home.homeDirectory = "/home/kali";
    home.stateVersion = "25.11";

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      OSCP_TARGET_ROOT = oscpRoot;
      PAYLOADS_DIR = payloadRoot;
      TERMINAL = "alacritty";
    };

    home.packages = with pkgs; [
      oras
    ];

    home.activation.ensurePentestDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p \
        "${oscpRoot}" \
        "${payloadRoot}/linux" \
        "${payloadRoot}/windows" \
        "$HOME/logs" \
        "${artifactLockerRoot}"
    '';

    home.file.".local/bin/pentest-check" = {
      executable = true;
      force = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        required=(
          artifact-locker
          payload-server
          new-target
          scan
          parse-ports
          penelope
          updog
        )

        for cmd in "''${required[@]}"; do
          command -v "$cmd" >/dev/null 2>&1 || {
            printf 'missing: %s\n' "$cmd" >&2
            exit 1
          }
        done

        printf 'pentest-check: ok\n'
      '';
    };
  };
}
