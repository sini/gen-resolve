{
  description = "gen-resolve — demand-driven higher-order RAG evaluator over algebraic scope graphs (Knuth 1968 attribute schedule + Vogt 1989 HOAG)";

  # Class B: 5 pure gen siblings. No nixpkgs input — the library (./lib) is nixpkgs-lib-free
  # (checked by ci/tests/purity.nix). nixpkgs is pulled ONLY in ci/ (the nix-unit harness + the
  # evalModules-equivalence oracle). gen-prelude is declared for the standalone ./default.nix
  # shim (which constructs the sibling libs, each of which takes prelude) — the .lib output below
  # does not take a direct prelude (it consumes the already-constructed sibling .lib values).
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
    gen-scope.url = "github:sini/gen-scope";
    gen-graph.url = "github:sini/gen-graph";
    gen-rebuild.url = "github:sini/gen-rebuild";
    gen-algebra.url = "github:sini/gen-algebra";
    gen-bind.url = "github:sini/gen-bind";
  };

  outputs =
    {
      gen-scope,
      gen-graph,
      gen-rebuild,
      gen-algebra,
      gen-bind,
      ...
    }:
    {
      lib = import ./lib {
        scope = gen-scope.lib;
        graph = gen-graph.lib;
        rebuild = gen-rebuild.lib;
        algebra = gen-algebra.lib;
        bind = gen-bind.lib;
      };
    };
}
