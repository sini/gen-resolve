{
  inputs = {
    gen.url = "github:sini/gen";
    gen-scope.url = "github:sini/gen-scope";
    gen-graph.url = "github:sini/gen-graph";
    gen-memo.url = "github:sini/gen-memo";
    gen-algebra.url = "github:sini/gen-algebra";
    gen-bind.url = "github:sini/gen-bind";
    # nixpkgs is the CI runner's dependency (nix-unit harness, treefmt) and supplies the
    # `lib` the test modules use — including the evalModules-equivalence oracle (DP5). The
    # library itself (../lib) is nixpkgs-lib-free (ci/tests/purity.nix enforces this).
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen,
      gen-scope,
      gen-graph,
      gen-memo,
      gen-algebra,
      gen-bind,
      ...
    }:
    let
      genResolve = import ../lib {
        scope = gen-scope.lib;
        graph = gen-graph.lib;
        memo = gen-memo.lib;
        algebra = gen-algebra.lib;
        bind = gen-bind.lib;
      };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-resolve";
      testModules = ./tests;
      specialArgs = {
        inherit genResolve;
        genScope = gen-scope.lib;
        genGraph = gen-graph.lib;
        genAlgebra = gen-algebra.lib;
        genBind = gen-bind.lib;
      };
    };
}
