# Intra-eval incremental override (design §9; DP3/DP6). isClean = the topological reverse cone
# (gen-graph.dependentsOf) — NOT gen-rebuild.affectedSet (DP6): exact-AFFECTED hash-detection would
# force (hash) the dominant per-host spine and evalWarm would force it again — a literal 2× of the
# dominant cost intra-eval — and only pays off cross-eval (deferred). gen-scope.evalWarm is the sole
# recompute engine.
# THEORY: RTD 1983 §4.3 — the topological reverse cone is a SOUND OVER-APPROXIMATION of AFFECTED
#         (RTD's AFFECTED is the cone MINUS the unchanged-value nodes; the §4.1 unchanged-value
#         cutoff that yields exact/optimal AFFECTED is the deferred cross-eval layer, NOT v1 — so
#         "reverse cone" != "AFFECTED", it is a superset that is always correct to recompute);
#         Acar 2002 §7 (reverse-topo splice); Mokhov 2018 §4.1 (laziness scopes the demanded part free).
{
  scope,
  graph,
  rebuild,
}:
let
  edgeKeys = [
    "includes"
    "neededBy"
    "__edges"
    "parent"
  ];
  changesTopology = _old: newDecls: builtins.any (k: newDecls ? ${k}) edgeKeys;

  # non-base (resolution-and-later) attrs are warm-served from the cold prior; base (index-0, graph-shaping)
  # attrs reshape the graph and always recompute (children/derived-children are never warm-served by
  # gen-scope.evalWarm anyway). `!= base` over the sealed `ctx.strataOrder` generalizes the shipped
  # `resolution|terminal` set to any declared order; the default reproduces it.
  trackedFor =
    ctx: _nid:
    let
      # dead-path default for hand-built ctxs (resolve seals ctx.strataOrder); mirrors schedule.defaultStrataOrder.
      base = builtins.head (
        ctx.strataOrder or [
          "structural"
          "resolution"
        ]
      );
    in
    builtins.filter (a: ctx.equations.${a}.stratum != base) (builtins.attrNames ctx.equations);

  # project prior clean values for warm reuse (lazy; collection-tier reads force O(n))
  priorFrom =
    ctx: cleanIds:
    builtins.listToAttrs (
      map (id: {
        name = id;
        value = builtins.listToAttrs (
          map (a: {
            name = a;
            value = ctx.eval.get id a;
          }) (trackedFor ctx id)
        );
      }) cleanIds
    );

  # DP4: fresh LAZY builtCtx over (eval', accessor') — the cross-eval hook, unforced in v1.
  mkBuiltCtx' =
    ctx: eval': accessor':
    rebuild.build {
      accessor = accessor';
      recompute =
        _acc: _store: nid:
        builtins.listToAttrs (
          map (a: {
            name = a;
            value = eval'.get nid a;
          }) (trackedFor ctx nid)
        );
      hashOf = v: builtins.hashString "sha256" (builtins.toJSON v);
    };

  # Core: splice a set of data-change edits, mark the union of their reverse cones dirty, one evalWarm.
  spliceAndWarm =
    ctx: edits: # edits :: { <id> = newDecls; }
    assert
      (builtins.all (id: builtins.hasAttr id ctx.roots) (builtins.attrNames edits))
      || throw "gen-resolve.override: edit target(s) must be root nodes — ${
        builtins.toJSON (builtins.filter (id: !(builtins.hasAttr id ctx.roots)) (builtins.attrNames edits))
      } not in roots (NTA-spawned nodes are not editable; edit the spawning root).";
    let
      ids = builtins.attrNames edits;
      roots' = builtins.foldl' (
        r: id:
        r
        // {
          ${id} = r.${id} // {
            decls = (r.${id}.decls or { }) // edits.${id};
          };
        }
      ) ctx.roots ids;
      accessor' = ctx.accessor // {
        nodeData = nid: (roots'.${nid} or { decls = { }; }).decls;
      };

      # DP3/DP6: dirty = the changed ids ∪ their topological reverse cones (over the edited accessor)
      cone = builtins.concatMap (id: graph.dependentsOf accessor' id) ids;
      dirty = builtins.foldl' (acc: n: acc // { ${n} = true; }) { } (ids ++ cone); # set for O(1) membership
      isClean = nid: !(dirty ? ${nid});

      attributes = builtins.mapAttrs (_: eq: eq.compute) ctx.equations; # schedule reused (D12)
      cleanIds = builtins.filter isClean (builtins.attrNames ctx.eval.allNodes);
      priorResults = priorFrom ctx cleanIds;

      eval' = scope.evalWarm {
        roots = roots';
        inherit attributes;
        parseParent = ctx.parseParent;
        inherit priorResults isClean;
      };

      trace' = builtins.listToAttrs (
        map (nid: {
          name = nid;
          value = {
            deps = scope.recordedDeps { declaredEdges = ctx.declaredEdges; } nid;
            hash = null;
          };
        }) (builtins.attrNames eval'.allNodes)
      );
      builtCtx' = mkBuiltCtx' ctx eval' accessor'; # lazy hook, unforced (DP4)
    in
    ctx
    // {
      roots = roots';
      eval = eval';
      accessor = accessor';
      builtCtx = builtCtx';
      trace = trace';
    };
  # schedule + equations + parseParent + declaredEdges + settings carried unchanged (D12)
in
{
  override =
    ctx:
    { id, newDecls }:
    assert
      !(changesTopology (ctx.roots.${id}.decls or { }) newDecls)
      || throw "gen-resolve.override: edge-move on '${id}' (topology change) — errors in v1; route to gen-rebuild.applyEdgeDelta in v2 (D14).";
    spliceAndWarm ctx { ${id} = newDecls; };

  # warmResolve — batch override (Task 8): guard each id, one union cone, one evalWarm. spliceAndWarm
  # already unions the cones and does a single warm pass, so this is a thin guard-and-delegate wrapper.
  # v1 takes { edits } (the {id=newDecls} map), reconciling design §6's { changedIds } (a bare id list
  # cannot carry the data-change payload a pure batch needs); changedIds = attrNames edits.
  warmResolve =
    ctx:
    { edits }:
    assert
      builtins.all (id: !(changesTopology (ctx.roots.${id}.decls or { }) edits.${id})) (
        builtins.attrNames edits
      )
      || throw "gen-resolve.warmResolve: edge-move in batch (topology change) — errors in v1 (D14).";
    spliceAndWarm ctx edits;

  inherit spliceAndWarm;
}
