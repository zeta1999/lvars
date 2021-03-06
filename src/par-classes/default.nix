# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ haskellPackages ? (import <nixpkgs> {}).haskellPackages
}:

with haskellPackages;
cabal.mkDerivation (self: {
  pname = "par-classes";
  version = "1.1";
  src = builtins.filterSource
    (path: (type:  baseNameOf path != ".git"))
    ./.;
  sha256 = "1yjqhym8n2ycavzhcqvywwav3r2hsjadidkwyvz4pdhn5q138aap";
  buildDepends = [ deepseq ];
  meta = {
    description = "Type classes providing a general interface to various @Par@ monads";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})
