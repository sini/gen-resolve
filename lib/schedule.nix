# The OWNED static schedule — Knuth 1968 attribute-dependency graph + circularity test. The gate
# discharges the Knuth / reduced-AG acyclicity half ONLY; Vogt 1989 §3.2 HOAG well-definedness
# (finite tree expansion of NTAs) is a RUNTIME concern — a non-terminating `spawn` diverges at eval,
# not at schedule time. Analysis over gen-graph topology, NOT a runtime scheduler (runtime order is
# demand — Mokhov 2018 §4.1, delegated to gen-scope).
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
      # Knuth 1968 circularity test (with Sloane 2009 for the circular-attr Kleene fixpoint): a cyclic
      # SCC is admissible iff every member is a declared `circular` attribute; else the AG is not convergent.
      badSccs = builtins.filter (
        scc: isCyclicScc scc && !(builtins.all (isCircular equations) scc)
      ) cond.sccs;

      # DP1 two-stratum partition assert. Honest anchor: Neron 2015 (staged name-resolution THEN
      # resolution) + den-hoag §B2. This enforces the pre-Statix two-stage discipline (van Antwerpen
      # 2016 §1) that the Statix unified solver was built to TRANSCEND — a sound static SUFFICIENT
      # condition for §4.3 stability, not the solver. Structural attrs (graph-builders) must not depend
      # on resolution attrs (graph-queriers), so every resolution query sees a structurally-complete
      # region. terminal is exempt (the sink).
      strat = a: equations.${a}.stratum;
      cone = a: graph.reachableFrom { edges = edges; } a; # transitive readsAttrs-cone (a excluded)
      violations = builtins.concatMap (
        a:
        if strat a == "structural" then
          map (b: {
            from = a;
            to = b;
          }) (builtins.filter (b: (equations ? ${b}) && strat b == "resolution") (cone a))
        else
          [ ]
      ) names;
    in
    if badSccs != [ ] then
      throw (
        "gen-resolve: attribute grammar is circular but not convergent (Knuth 1968 circularity test). "
        + "SCC(s) contain non-`circular` attrs: ${builtins.toJSON badSccs}. "
        + "Declare kind=\"circular\" (Sloane 2009 iterate-to-fixpoint) or break the cycle."
      )
    else if violations != [ ] then
      throw (
        "gen-resolve: two-stratum partition violated (van Antwerpen 2016 §4.3). "
        + "Structural attr(s) reach a resolution attr: ${builtins.toJSON violations}. "
        + "A graph-building attr must not depend on a resolution result."
      )
    else
      {
        inherit equations;
        attrGraph = attrAccessor;
        condensation = cond;
        inherit edges;
      };
}
