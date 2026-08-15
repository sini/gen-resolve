# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-resolve is Class B: {gen-scope, gen-graph, gen-algebra, gen-bind}. This shim derives all four
# from the pinned flake.lock (content-addressed via narHash, so it stays pure) and needs no
# `<nixpkgs>`. Each DEP-BEARING sibling flake `.lib` self-resolves its own deps, so this shim imports
# that sibling's standalone entry, which self-constructs: a `lib/` formal list is that library's
# private contract and gains members without notice to this file. gen-algebra is dep-free — its lib
# is a bare value and its entry IS that value, so it is imported directly and applied to nothing.
# Pass any dep explicitly to override.
{
  lock ? builtins.fromJSON (builtins.readFile ./flake.lock),
  # Resolve each direct input via root.inputs indirection — the plain node names
  # (`gen-scope`, `gen-graph`, …) can be TRANSITIVE aliases (`gen-graph_2`), so
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
  algebra ? import "${fetch "gen-algebra"}/lib",
  scope ? import "${fetch "gen-scope"}" { },
  graph ? import "${fetch "gen-graph"}" { },
  bind ? import "${fetch "gen-bind"}" { },
  ...
}:
import ./lib {
  inherit
    scope
    graph
    algebra
    bind
    ;
}
