{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  glib,
  gtk3,
  libdrm,
  libGL,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  libayatana-appindicator,
  libseccomp,
  libcap_ng,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxtst,
  libxshmfence,
  # runtime tools threaded onto the app's PATH (Cowork VM + link handling)
  qemu_kvm,
  OVMF,
  xdg-utils,
}:

let
  version = "1.21459.0";
  # Latest at: https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-<arch>/Packages
  sources = {
    "x86_64-linux" = {
      debArch = "amd64";
      sha256 = "7d0193d9767a8d9ea830c29cc2c9d2f62f83a206808a18b159911d4328990c5b";
    };
    # "aarch64-linux" = { debArch = "arm64"; sha256 = "..."; };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "claude-desktop: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit version;

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_${source.debArch}.deb";
    inherit (source) sha256;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];
  dontWrapGApps = true; # bin is a symlink into lib; wrap the real binary ourselves

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libGL
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    vulkan-loader
    libayatana-appindicator
    libseccomp
    libcap_ng
    stdenv.cc.cc.lib
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
    libxshmfence
  ];

  # Pipe through tar with --no-same-permissions so the setuid chrome-sandbox bit
  # (which the build sandbox can't set) doesn't abort extraction; it's removed anyway.
  unpackPhase = ''
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner --no-same-permissions
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/share
    cp -r usr/lib/claude-desktop $out/lib/
    cp -r usr/share/applications usr/share/icons $out/share/ 2>/dev/null || true
    # SUID chrome-sandbox can't work from the store; drop it → Chromium uses the
    # unprivileged-userns namespace sandbox (enabled by default on NixOS).
    rm -f $out/lib/claude-desktop/chrome-sandbox
    runHook postInstall
  '';

  # Wrap the launcher: GApps env + a runtime PATH (qemu/OVMF for the Cowork VM,
  # xdg-utils for links) + LD_LIBRARY_PATH for the GL libs ANGLE dlopens at runtime.
  postFixup = ''
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ qemu_kvm xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd libGL mesa vulkan-loader ]} \
      --set-default OVMF_PATH ${OVMF.fd}/FV/OVMF_CODE.fd \
      --add-flags "--ozone-platform-hint=auto --password-store=gnome-libsecret"
    substituteInPlace $out/share/applications/*.desktop \
      --replace-quiet "Exec=claude-desktop" "Exec=$out/bin/claude-desktop"
  '';

  meta = {
    description = "Claude desktop app (Chat, Cowork, Code) — repacked from Anthropic's Linux beta .deb";
    homepage = "https://claude.ai";
    downloadPage = "https://code.claude.com/docs/en/desktop-linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames sources;
    mainProgram = "claude-desktop";
  };
}
