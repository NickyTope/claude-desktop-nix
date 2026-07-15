self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude-desktop;
in
{
  options.programs.claude-desktop = {
    enable = lib.mkEnableOption "the Claude desktop app (Chat, Cowork, Code)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop;
      defaultText = lib.literalExpression "claude-desktop.packages.\${system}.claude-desktop";
      description = "The claude-desktop package to install.";
    };

    cowork.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Wire the host bits the Cowork/Code sandbox needs on NixOS:
        - {command}`nix-ld`, so the downloaded (generic-linux) Claude Code CLI runs
          for local sessions;
        - the Debian FHS paths the microVM hardcodes for its EDK2 firmware and
          virtiofsd (symlinked to the nixpkgs versions).

        QEMU itself is already on the app's PATH via the package wrapper. You still
        need access to {file}`/dev/kvm` (e.g. be in the `kvm` group).
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    { environment.systemPackages = [ cfg.package ]; }

    (lib.mkIf cfg.cowork.enable {
      # The "local" Claude Code session spawns a generic dynamically-linked binary
      # (~/.config/Claude/claude-code/<ver>/claude); nix-ld provides the loader.
      programs.nix-ld.enable = lib.mkDefault true;

      # The Cowork/Code microVM reads these Debian-convention absolute paths at boot
      # (EDK2 CODE + VARS templates, virtiofsd). Point them at the nixpkgs builds.
      systemd.tmpfiles.rules = [
        "L+ /usr/share/OVMF/OVMF_CODE.fd    - - - - ${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
        "L+ /usr/share/OVMF/OVMF_CODE_4M.fd - - - - ${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
        "L+ /usr/share/OVMF/OVMF_VARS.fd    - - - - ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"
        "L+ /usr/share/OVMF/OVMF_VARS_4M.fd - - - - ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"
        "L+ /usr/libexec/virtiofsd          - - - - ${pkgs.virtiofsd}/bin/virtiofsd"
      ];
    })
  ]);
}
