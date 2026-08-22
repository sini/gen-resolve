{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    gen-scope.url = "github:sini/gen-scope";
    gen-graph.url = "github:sini/gen-graph";
    gen-algebra.url = "github:sini/gen-algebra";
    gen-bind.url = "github:sini/gen-bind";
    # nixpkgs is the CI runner's dependency (nix-unit harness, treefmt) and supplies the
    # `lib` the test modules use — including the evalModules-equivalence oracle (DP5). The
    # library itself (../lib) is nixpkgs-lib-free (ci/tests/purity.nix enforces this).
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-scope,
      gen-graph,
      gen-algebra,
      gen-bind,
      ...
    }:
    let
      genResolve = import ../lib {
        scope = gen-scope.lib;
        graph = gen-graph.lib;
        algebra = gen-algebra.lib;
        bind = gen-bind.lib;
      };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-resolve";
      testModules = ./tests;
      specialArgs = {
        inherit genResolve;
        genScope = gen-scope.lib;
        genGraph = gen-graph.lib;
        genAlgebra = gen-algebra.lib;
        genBind = gen-bind.lib;
        # THE PLANE IS NO LONGER AN INPUT HERE. The cells that composed it with this evaluator's
        # accessor were the only site in the ecosystem forcing `gen-memo.build`, and they have
        # re-sited to gen-memo's own suite, where the construct they oracle actually lives. A
        # retiring library holding an input nothing reaches is a coupling with no reader.
      };
      # Cells whose subject is an ABORT cannot live under `testModules`: the batch asserter behind
      # `checks.default` quantifies over `flake.tests` and forces every `expr` unconditionally, so
      # an aborting one crashes that gate instead of failing a cell. They get their own output, read
      # by `nix-unit --flake ./ci#testsError`.
      extraModules = [
        ./tests-error.nix
      ];
    };
}
