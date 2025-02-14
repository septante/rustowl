{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    rust-overlay,
    ...
  }:
  let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems
      (system: f { pkgs = import nixpkgs { inherit system overlays; }; });

    overlays = [
      rust-overlay.overlays.default
      (_: prev: {
          rust-toolchain = prev.rust-bin.fromRustupToolchainFile ./rustowl/rust-toolchain.toml;
      })
    ];

    getRustPlatform = pkgs: pkgs.makeRustPlatform {
      cargo = pkgs.rust-bin.selectLatestNightlyWith (toolchain: pkgs.rust-toolchain);
      rustc = pkgs.rust-bin.selectLatestNightlyWith (toolchain: pkgs.rust-toolchain);
    };

    rustowl = ./rustowl;

    version = (builtins.fromTOML (builtins.readFile "${rustowl}/Cargo.toml")).package.version;
  in
  {
    devShells = forAllSystems ({ pkgs }: with pkgs; {
      default = mkShell rec {
        buildInputs = [
          rust-toolchain
        ];
        LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
      };
    });

    packages = forAllSystems ({ pkgs }: {
      default = (getRustPlatform pkgs).buildRustPackage {
        pname = "cargo-owlsp";
        src = rustowl;
        inherit version;

        cargoLock = {
          lockFile = rustowl + /Cargo.lock;
        };
      };
    });
  };
}
