{
  description = "gen-resolve example §5.1 — abstract attribute-DAG + neron cascade (default<env<host<policy)";

  # Pre-publish: eval with `--override-input gen-resolve ../..`. Post-publish the pins resolve directly.
  # dag needs no nixpkgs — it is pure gen-resolve + gen-scope (no evalModules / lib.* in the example).
  inputs = {
    gen-resolve.url = "github:sini/gen-resolve";
    gen-scope.url = "github:sini/gen-scope";
  };

  outputs =
    {
      gen-resolve,
      gen-scope,
      ...
    }:
    {
      result = import ./default.nix {
        genResolve = gen-resolve.lib;
        genScope = gen-scope.lib;
      };
    };
}
