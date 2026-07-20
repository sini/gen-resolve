# The OWNED static schedule — Knuth 1968 attribute-dependency graph + circularity test. The gate
# discharges the Knuth / reduced-AG acyclicity half ONLY; Vogt 1989 §3.2 HOAG well-definedness
# (finite tree expansion of NTAs) is a RUNTIME concern — a non-terminating `spawn` diverges at eval,
# not at schedule time. Analysis over gen-graph topology, NOT a runtime scheduler (runtime order is
# demand — Mokhov 2018 §4.1, delegated to gen-scope).
{ graph }:
let
  circularKinds = [ "circular" ];
  isCircular = eqs: a: builtins.elem (eqs.${a}.kind) circularKinds;

  # DP1 default: the shipped two-stratum order. `scheduleWith` generalizes to any declared order;
  # `buildSchedule eqs` = `scheduleWith { equations = eqs; }` reproduces the structural<resolution case.
  defaultStrataOrder = [
    "structural"
    "resolution"
  ];

  # position of a stratum name in the declared order; null if absent (caught by the unknown-stratum guard).
  posOf =
    strataOrder: s:
    let
      hits = builtins.filter (i: builtins.elemAt strataOrder i == s) (
        builtins.genList (i: i) (builtins.length strataOrder)
      );
    in
    if hits == [ ] then null else builtins.head hits;

  scheduleWith =
    {
      equations,
      strataOrder ? defaultStrataOrder,
    }:
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

      # DP1 N-way stratum partition assert. Honest anchor: Neron 2015 (staged name-resolution THEN
      # resolution) + den-hoag §B2. Generalizes the shipped two-stratum discipline (van Antwerpen 2016
      # §1, the pre-Statix two-stage sufficient condition) to a declared TOTAL order `strataOrder`
      # (index 0 = the base graph-shaping stratum). Apt–Blair–Walker 1988: a rule may read predicates at
      # strata ≤ its own (positive dep); reading a STRICTLY-LATER stratum is the violation (a rule at an
      # earlier stratum depending on a not-yet-resolved later stratum). `terminal` is the sink (the Vogt
      # materialization boundary) — exempt (reads any stratum). Subsumes the shipped case: order
      # [structural resolution], structural(0) reading resolution(1) → 1 > 0 → violation.
      strat = a: equations.${a}.stratum;
      pos = posOf strataOrder;
      cone = a: graph.reachableFrom { edges = edges; } a; # transitive readsAttrs-cone (a excluded)
      # every non-terminal attr's declared stratum must name a stratum in the order.
      unknownStrata = builtins.filter (a: strat a != "terminal" && pos (strat a) == null) names;
      violations = builtins.concatMap (
        a:
        if strat a == "terminal" then
          [ ]
        else
          let
            pa = pos (strat a);
          in
          map
            (b: {
              from = a;
              to = b;
            })
            (
              builtins.filter (
                b:
                (equations ? ${b})
                && (strat b != "terminal")
                && (
                  let
                    pb = pos (strat b);
                  in
                  pb != null && pb > pa
                )
              ) (cone a)
            )
      ) names;
    in
    if badSccs != [ ] then
      throw (
        "gen-resolve: attribute grammar is circular but not convergent (Knuth 1968 circularity test). "
        + "SCC(s) contain non-`circular` attrs: ${builtins.toJSON badSccs}. "
        + "Declare kind=\"circular\" (Sloane 2009 iterate-to-fixpoint) or break the cycle."
      )
    else if unknownStrata != [ ] then
      throw (
        "gen-resolve: attribute '${builtins.head unknownStrata}' declares stratum "
        + "'${strat (builtins.head unknownStrata)}' not in the declared order ${builtins.toJSON strataOrder} "
        + "(and is not the exempt `terminal` sink)."
      )
    else if violations != [ ] then
      throw (
        "gen-resolve: stratum partition violated (van Antwerpen 2016 §4.3; N-way generalization, "
        + "Apt–Blair–Walker 1988). Attr(s) read a strictly-later stratum: ${builtins.toJSON violations}. "
        + "A rule may read only strata at or below its own in the declared order ${builtins.toJSON strataOrder}."
      )
    else
      {
        inherit equations;
        attrGraph = attrAccessor;
        condensation = cond;
        inherit edges;
      };
in
{
  inherit scheduleWith;
  # back-compat: the shipped two-stratum entry (default order).
  buildSchedule = equations: scheduleWith { inherit equations; };
}
