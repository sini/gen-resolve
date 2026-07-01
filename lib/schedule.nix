# The OWNED static schedule — Knuth 1968 attribute-dependency graph + the circularity test,
# lifted to the higher-order setting (Vogt 1989 §2). This is analysis over gen-graph topology,
# NOT a runtime scheduler (runtime order is demand — Mokhov 2018 §4.1, delegated to gen-scope).
{ graph }:
let
  circularKinds = [ "circular" ];
  isCircular = eqs: a: builtins.elem (eqs.${a}.kind) circularKinds;
in
{
  buildSchedule =
    equations:
    let
      names = builtins.attrNames equations;
      # attr-dep edges: a depends on b iff b in readsAttrs a (b must be a defined attr)
      edges = a: builtins.filter (b: equations ? ${b}) (equations.${a}.readsAttrs or [ ]);
      attrAccessor = {
        nodes = names;
        edges = edges;
      };
      cond = graph.condensation attrAccessor; # { sccs :: [[name]]; ... }

      selfLoop = a: builtins.elem a (edges a);
      isCyclicScc =
        scc: (builtins.length scc > 1) || (builtins.length scc == 1 && selfLoop (builtins.head scc));
      # Vogt/Knuth gate: a cyclic SCC is well-defined iff every member is a declared circular attribute.
      badSccs = builtins.filter (
        scc: isCyclicScc scc && !(builtins.all (isCircular equations) scc)
      ) cond.sccs;
    in
    if badSccs != [ ] then
      throw (
        "gen-resolve: attribute grammar is circular but not convergent (Knuth 1968 circularity test). "
        + "SCC(s) contain non-`circular` attrs: ${builtins.toJSON badSccs}. "
        + "Declare kind=\"circular\" (Sloane 2009 iterate-to-fixpoint) or break the cycle."
      )
    else
      {
        inherit equations;
        attrGraph = attrAccessor;
        condensation = cond;
        inherit edges;
      };
}
