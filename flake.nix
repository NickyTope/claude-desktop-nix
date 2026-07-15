{
  description = "Claude desktop app (Chat, Cowork, Code) for NixOS — repacked from Anthropic's official Linux .deb, with a module that makes the Cowork/Code microVM work out of the box.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true; # claude-desktop is unfree
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          claude-desktop = pkgs.callPackage ./package.nix { };
          default = claude-desktop;
        }
      );

      overlays.default = final: _prev: {
        claude-desktop = final.callPackage ./package.nix { };
      };

      nixosModules.default = import ./module.nix self;

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);
    };
}
