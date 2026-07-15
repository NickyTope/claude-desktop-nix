# claude-desktop-nix

A Nix flake for the **Claude desktop app on Linux** (the official beta with the
**Chat, Cowork, and Code** tabs), repacked from Anthropic's own `.deb` — *not* the
macOS app. It ships a NixOS module that also wires up the non-obvious host bits the
**Cowork/Code microVM** needs, so it works out of the box instead of erroring with
"Cowork requires QEMU" or "Claude Code crashed".

> Anthropic distributes the Linux app only as a Debian/Ubuntu `.deb` via apt
> ([docs](https://code.claude.com/docs/en/desktop-linux)); there is no NixOS package.
> This flake tracks that `.deb`.

## Quick start (NixOS flake)

```nix
# flake.nix
{
  inputs.claude-desktop.url = "github:NickyTope/claude-desktop-nix";

  outputs = { nixpkgs, claude-desktop, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        claude-desktop.nixosModules.default
        { programs.claude-desktop.enable = true; }
      ];
    };
  };
}
```

`claude-desktop` is unfree — set `nixpkgs.config.allowUnfree = true;` (or an
`allowUnfreePredicate` for `claude-desktop`).

Then `claude-desktop` is on your PATH and in your app launcher. Sign in with your
claude.ai subscription or org SSO.

### Just the package

```nix
environment.systemPackages = [ inputs.claude-desktop.packages.${system}.default ];
```

or via the overlay:

```nix
nixpkgs.overlays = [ inputs.claude-desktop.overlays.default ];
```

or ad-hoc: `nix run github:NickyTope/claude-desktop-nix`

## What the module does

`programs.claude-desktop.enable` installs the app. With `programs.claude-desktop.cowork.enable`
(default **true**) it also:

- enables **`nix-ld`** — the "local" Claude Code session runs a downloaded,
  generic-linux dynamic binary (`~/.config/Claude/claude-code/<ver>/claude`) that
  NixOS otherwise can't exec;
- symlinks the **Debian FHS paths the microVM hardcodes** to the nixpkgs builds —
  the EDK2 firmware (`/usr/share/OVMF/OVMF_{CODE,VARS}{,_4M}.fd`) and
  `/usr/libexec/virtiofsd`.

QEMU is bundled onto the app's PATH by the package wrapper. **You still need
`/dev/kvm` access** — be in the `kvm` group (most configs with
`virtualisation.libvirtd`/`virtualisation.docker` + KVM already are), otherwise the
Cowork/Code VM won't boot.

Set `cowork.enable = false;` if you only want Chat/Code-without-sandbox and would
rather not enable nix-ld or touch `/usr`.

## How it's packaged

- `fetchurl` the `.deb`; `dpkg-deb` extract; `autoPatchelfHook` against nixpkgs
  (incl. the bundled `virtiofsd`, `chrome-native-host`, `cowork-linux-helper`).
- `chrome-sandbox` (SUID) is dropped → Chromium uses the unprivileged-userns
  namespace sandbox.
- Wrapper adds: `--ozone-platform-hint=auto` (Wayland), `--password-store=gnome-libsecret`
  (keyring on non-GNOME sessions), `qemu`/`xdg-utils` on PATH, and GL libs on
  `LD_LIBRARY_PATH` (ANGLE `dlopen`s `libEGL.so.1` at runtime).

## Updating

Bump `version` + `sha256` in `package.nix`. Find the newest build in the apt index:

```bash
curl -fsSL https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
  | awk '/^Version:/{v=$2} /^SHA256:/{s=$2} /^$/{if(v)print v,s; v=s=""}' | sort -V | tail -1
```

## Status / caveats

- **x86_64-linux** only for now. (The `.deb` has an `arm64` build + `AAVMF`
  firmware; add an `aarch64-linux` entry to `sources` in `package.nix` — PRs welcome.)
- Tracks a **beta**; expect churn.
- Computer Use and dictation aren't in the Linux beta yet.

## License

The packaging (this repo) is MIT. **Claude Desktop itself is proprietary** —
Anthropic's [Consumer Terms](https://www.anthropic.com/legal/consumer-terms) /
[Usage Policy](https://www.anthropic.com/legal/aup) apply. This flake only fetches
and repackages Anthropic's published binary; it is not affiliated with Anthropic.
