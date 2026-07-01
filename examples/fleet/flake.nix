{
  description = "gen-resolve example §5.3 — den fleet: cross-host includes, override cone, classKey collapse";

  # Pre-publish: eval with `--override-input gen-resolve ../..`. Post-publish the pins resolve directly.
  inputs = {
    gen-resolve.url = "github:sini/gen-resolve";
    gen-scope.url = "github:sini/gen-scope";
    gen-aspects.url = "github:sini/gen-aspects";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    {
      gen-resolve,
      gen-scope,
      gen-aspects,
      nixpkgs,
      ...
    }:
    {
      result = import ./default.nix {
        genResolve = gen-resolve.lib;
        genScope = gen-scope.lib;
        genAspects = gen-aspects.lib;
        lib = nixpkgs.lib;
      };
    };
}
