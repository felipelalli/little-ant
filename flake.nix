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
        # Keep the compiler pinned to the release toolchain even after a flake update.
        haskellPackages = pkgs.haskell.packages.ghc9103;
        packageName = "little-ant";
        ageFfi = pkgs.rustPlatform.buildRustPackage {
          pname = "lant-age-ffi";
          version = "1.0.0";
          src = ./rust/lant-age-ffi;
          cargoHash = "sha256-8QPuAZ30aesU2b3NJnzrOTX9SiY8+VAitkytc4Bs47k=";
          doCheck = true;
          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib
            cp target/*/release/liblant_age_ffi.a $out/lib/
            runHook postInstall
          '';
        };
        pkgBase = haskellPackages.callCabal2nix packageName self {
          lant_age_ffi = ageFfi;
        };
        pkg = pkgBase.overrideAttrs (old: {
          __intentionallyOverridingVersion = true;
          version = "1.0.0-alpha.1";
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.taskjuggler ];
          postInstall = (old.postInstall or "") + ''
            mkdir -p $out/libexec/little-ant
            mv $out/bin/lant-pack-runner $out/libexec/little-ant/lant-pack-runner
          '';
        });
      in {
        packages.${packageName} = pkg;
        packages.lant-age-ffi = ageFfi;
        packages.default = pkg;

        apps.default = {
          type = "app";
          program = "${pkg}/bin/lant";
        };

        devShells.default = pkgs.mkShell {
          # Keep interactive bash available to tools that re-exec through env.
          packages = [ pkgs.bashInteractive pkgs.taskjuggler ];
          buildInputs = with haskellPackages; [
            ghc
            cabal-install
            haskell-language-server
            cabal-fmt
            fourmolu
            hlint
          ];
          inputsFrom = [ pkg.env ];
        };
      });
}
