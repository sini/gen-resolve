{
  description = "gen-resolve — demand-driven higher-order RAG evaluator over algebraic scope graphs (Knuth 1968 attribute schedule + Vogt 1989 HOAG)";

  # Class B: 4 pure gen siblings. No nixpkgs input — the library (./lib) is nixpkgs-lib-free
  # (checked by ci/tests/purity.nix). nixpkgs is pulled ONLY in ci/ (the nix-unit harness + the
  # evalModules-equivalence oracle). gen-prelude is NOT declared: the .lib output takes no direct
  # prelude, and the standalone ./default.nix shim takes each sibling at its own standalone entry,
  # which resolves its prelude from that sibling's own lock. A prelude pinned here would be a
  # revision no consumer of this library ever evaluates.
  inputs = {
    gen-scope.url = "github:sini/gen-scope";
    gen-graph.url = "github:sini/gen-graph";
    gen-algebra.url = "github:sini/gen-algebra";
    gen-bind.url = "github:sini/gen-bind";
  };

  outputs =
    {
      gen-scope,
      gen-graph,
      gen-algebra,
      gen-bind,
      ...
    }:
    {
      lib = import ./lib {
        scope = gen-scope.lib;
        graph = gen-graph.lib;
        algebra = gen-algebra.lib;
        bind = gen-bind.lib;
      };
    };
}
