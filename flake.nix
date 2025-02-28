{
  description = "Meshtastic (native) for NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }@inputs: let
    allSystems = nixpkgs.lib.systems.flakeExposed;
    forSystems = systems: f: nixpkgs.lib.genAttrs systems (system: f system);
  in {

    devShells = forSystems allSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        name = "nixos-meshtastic";
        nativeBuildInputs = with pkgs; [
          nil # lsp language server for nix
          nixpkgs-fmt
          nix-output-monitor
        ];
      };
    });

    nixosModules = {
      default = import ./modules/meshtastic.nix self;

      # Tries to automagically configure SPI and I2C on Raspberry Pi
      # with `config.txt`
      # requires nvmd/nixos-raspberrypi
      raspberry-pi = import ./modules/raspberry-pi.nix;
    };

    packages = forSystems allSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {

      meshtasticd = pkgs.callPackage ./pkgs/meshtasticd.nix {
        inherit (self.packages.${system}) libyaml-cpp ulfius;
      };

      libyaml-cpp = pkgs.callPackage ./pkgs/libyaml-cpp.nix {};
      ulfius = pkgs.callPackage ./pkgs/ulfius.nix {};

    });

  };

}
