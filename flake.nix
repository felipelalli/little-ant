{
  description = "Little Ant — a personal focus engine. One brick at a time.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # Pinned explicitly (matches the default haskellPackages in the locked
        # nixpkgs) so a future `nix flake update` can't silently bump the GHC
        # major version out from under the project.
        haskellPackages = pkgs.haskell.packages.ghc9103;
        packageName = "little-ant";
        pkg = haskellPackages.callCabal2nix packageName self { };
      in {
        packages.${packageName} = pkg;
        packages.default = pkg;

        apps.default = {
          type = "app";
          program = "${pkg}/bin/la";
        };

        devShells.default = pkgs.mkShell {
          # The stdenv puts a readline-less `bash` on PATH; tools that re-exec
          # themselves via `env bash` (git-sh, for one) then lose `complete`.
          packages = [ pkgs.bashInteractive ];
          buildInputs = with haskellPackages; [
            ghc
            cabal-install
            haskell-language-server
          ];
          inputsFrom = [ pkg.env ];
        };
      });
}
