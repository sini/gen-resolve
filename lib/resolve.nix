# Cold resolve — folds equations into the demand fixpoint and seals the ResolveCtx.
# THEORY: Mokhov 2018 §4.1 (Nix laziness = the runtime schedule); the static schedule is Task 2/3.
{
  scope,
  rebuild,
  schedule,
}:
let
  # The resolution+terminal stratum attrs — warm-served on override (DP3); also the DP4 hash target
  # for the DEFERRED cross-eval layer. Structural attrs shape the graph and are never warm-served.
  trackedAttrs =
    equations:
    builtins.filter (
      a:
      let
        s = equations.${a}.stratum;
      in
      s == "resolution" || s == "terminal"
    ) (builtins.attrNames equations);

  snapshot =
    equations: ev: id:
    builtins.listToAttrs (
      map (a: {
        name = a;
        value = ev.get id a;
      }) (trackedAttrs equations)
    );

  # DP4: the gen-rebuild oracle over a given eval + accessor. Built per (eval, accessor); its recompute
  # reads its OWN paired eval, so its hashes are correct for the cross-eval detection use. It is a LAZY
  # ResolveCtx field — NEVER forced by v1 resolve/materialize/override (which use the topological cone,
  # DP3), so gen-rebuild's eager node-cycle check never trips. Activated only by the cross-invocation layer.
  mkBuiltCtx =
    equations: ev: accessor:
    rebuild.build {
      inherit accessor;
      recompute =
        _acc: _store: id:
        snapshot equations ev id; # reads its paired eval (correct for cross-eval)
      hashOf = v: builtins.hashString "sha256" (builtins.toJSON v); # function-bearing -> gen-rebuild nulls -> always-dirty
    };
in
{
  inherit mkBuiltCtx trackedAttrs snapshot;

  resolve =
    {
      roots,
      equations,
      parseParent,
      declaredEdges ? (_: [ ]),
      settings ? { },
    }:
    let
      sched = schedule.buildSchedule equations; # Vogt gate + stratum assert (throws propagate)
      attributes = builtins.mapAttrs (_: eq: eq.compute) equations; # design §8-step3
      eval = scope.eval { inherit roots attributes parseParent; }; # lib.fix demand fixpoint (delegate)

      nodeIds = builtins.attrNames eval.allNodes; # includes NTA-spawned children
      accessor = {
        nodes = nodeIds;
        edges = declaredEdges; # consumer->producer (must over-declare, soundness (c))
        parent = id: parseParent id;
        nodeData = id: (eval.node id).decls or { };
      };
      trace = builtins.listToAttrs (
        map (id: {
          name = id;
          value = {
            deps = scope.recordedDeps { inherit declaredEdges; } id; # eager, declared read-edges
            hash = null; # DP4: populated only by the deferred cross-eval layer
          };
        }) nodeIds
      );

      builtCtx = mkBuiltCtx equations eval accessor; # DP4: LAZY field, unforced in v1 (cross-eval hook)
    in
    # Force the schedule at resolve time (§8-step2): the Vogt gate + stratum assert live inside
    # buildSchedule's `if bad then throw else {…}`, so `seq sched` makes an invalid grammar throw
    # HERE, not lazily later (the gate would be inert if `ctx.schedule` were never forced).
    builtins.seq sched {
      inherit
        eval
        accessor
        builtCtx
        trace
        roots
        equations
        parseParent
        declaredEdges
        settings
        ;
      schedule = sched; # carry the resolved schedule (D12 edit-invariant)
    };
}
