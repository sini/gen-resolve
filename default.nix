# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-resolve is Class B: gen-prelude base + {gen-scope, gen-graph, gen-rebuild,
# gen-algebra, gen-bind}. This shim derives all six from the pinned flake.lock
# (content-addressed via narHash, so it stays pure) and needs no `<nixpkgs>`.
# Each dep is constructed with exactly the args its lib/default.nix takes:
#   gen-prelude, gen-algebra : argless bare-value libs
#   gen-scope, gen-graph, gen-bind : { prelude }
#   gen-rebuild : { prelude, graph, scope }
# Pass any dep explicitly to override.
{
  lock ? builtins.fromJSON (builtins.readFile ./flake.lock),
  # Resolve each direct input via root.inputs indirection — the plain node names
  # (`gen-prelude`, `gen-scope`, …) can be TRANSITIVE aliases (`gen-prelude_3`), so
  # dereference root.inputs.<name> to the actual node key before fetching.
  fetch ?
    name:
    builtins.fetchTree (
      let
        node = lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
      in
      {
        inherit (node)
          type
          owner
          repo
          rev
          narHash
          ;
      }
    ),
  prelude ? import "${fetch "gen-prelude"}/lib",
  algebra ? import "${fetch "gen-algebra"}/lib",
  scope ? import "${fetch "gen-scope"}/lib" { inherit prelude; },
  graph ? import "${fetch "gen-graph"}/lib" { inherit prelude; },
  rebuild ? import "${fetch "gen-rebuild"}/lib" { inherit prelude graph scope; },
  bind ? import "${fetch "gen-bind"}/lib" { inherit prelude; },
  ...
}:
# `prelude` above is the builder for the sibling libs (scope/graph/rebuild/bind each take it);
# ./lib itself takes only the 5 constructed siblings, not a direct prelude.
import ./lib {
  inherit
    scope
    graph
    rebuild
    algebra
    bind
    ;
}
