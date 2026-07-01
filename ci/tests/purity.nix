# Purity invariant (gen-prelude design §5): the gen-resolve library (./lib) is
# nixpkgs-lib-free. It depends only on gen-prelude + {gen-scope, gen-graph,
# gen-rebuild, gen-algebra, gen-bind} — all pure siblings. This pins "pure" as a
# checked property: a stray `lib.foo` / `lib.types` / `evalModules` / `mkOption` /
# nixpkgs input creeping back into the library source fails CI. (gen-algebra IS a
# legitimate dep here, so its tokens are NOT forbidden — unlike gen-derive.)
#
# Scope: lib/**.nix (recursively) + the root flake.nix + default.nix. NOT ci/ — the
# test harness legitimately uses nixpkgs.lib (including, here, to scan and for the
# DP5 evalModules-equivalence oracle).
{ lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here
  # because `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # Recursively collect every .nix under a directory.
  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  # Tokens signalling a nixpkgs-lib tether or the module-system tier.
  forbidden = [
    "nixpkgs"
    "lib."
    "{ lib }"
    "{ lib,"
    "evalModules"
    "mkOption"
  ];

  violations = lib.concatMap (
    src: map (tok: "${src.name}: '${tok}'") (lib.filter (tok: lib.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-dependency-free = {
    expr = violations;
    expected = [ ];
  };
}
