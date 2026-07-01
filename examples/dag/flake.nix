{
  description = "gen-resolve example §5.1 — abstract attribute-DAG + neron cascade (default<env<host<policy)";

  # Pre-publish: eval with `--override-input gen-resolve ../..`. Post-publish the pins resolve directly.
  inputs = {
    gen-resolve.url = "github:sini/gen-resolve";
    gen-scope.url = "github:sini/gen-scope";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    {
      gen-resolve,
      gen-scope,
      nixpkgs,
      ...
    }:
    {
      result = import ./default.nix {
        genResolve = gen-resolve.lib;
        genScope = gen-scope.lib;
        lib = nixpkgs.lib;
      };
    };
}
