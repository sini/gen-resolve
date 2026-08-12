# Cold resolve — folds equations into the demand fixpoint and seals the ResolveCtx.
#
# THEORY: Mokhov, Mitchell & Peyton Jones (2018) supply the scheduler/rebuilder decomposition this
# library sits inside; the mapping of the SCHEDULER half onto Nix's own laziness is this ecosystem's,
# not a sentence of that paper's. (Measured at the archived extraction: `laziness` and `demand` each
# occur 0 times, against live controls `scheduler` ⇒ 49 and `rebuilder` ⇒ 70 lines in the same run,
# and §4.1 is that paper's SCHEDULERS section. The mapping is defensible; the attribution that stood
# here was not.) The static attribute-dependency schedule is `schedule.nix`.
{
  scope,
  memo,
  schedule,
}:
let
  defaultStrataOrder = schedule.defaultStrataOrder;

  # The plane's memo ctx over a given eval + accessor. Built per (eval, accessor); its recompute reads
  # its OWN paired eval, so its hashes describe that evaluation and no other. It is a LAZY ResolveCtx
  # field that nothing on the cold path forces, so the store's eager node-cycle check is never reached
  # by a cold resolve. It is the hook a reuse layer ACROSS evaluations would enter through, and that
  # layer is a recorded growth path rather than shipped scope.
  #
  # THE PROJECTION IS READ OFF THE EVALUATOR AND IS NOT COMPUTED HERE. What may be reused is the
  # evaluator's own resolutional vocabulary — its attribute names minus the structural partition —
  # which it publishes per node. The filter that stood here decided the same question from a DECLARED
  # stratum and has been superseded: a derived classifier governs over a declaration, the derivation
  # is available, and keeping a second answer to one question in a second library is how the two come
  # to disagree.
  mkBuiltCtx =
    ev: accessor:
    memo.build {
      inherit accessor;
      recompute =
        _acc: _store: id:
        builtins.listToAttrs (
          map (a: {
            name = a;
            value = ev.get id a;
          }) (ev.resolutional id)
        );
      hashOf = v: builtins.hashString "sha256" (builtins.toJSON v); # function-bearing -> the plane nulls the hash -> always-dirty
    };
in
{
  inherit mkBuiltCtx;

  resolve =
    {
      roots,
      equations,
      parseParent,
      declaredEdges ? (_: [ ]),
      settings ? { },
      strataOrder ? defaultStrataOrder,
    }:
    let
      sched = schedule.scheduleWith { inherit equations strataOrder; }; # Vogt gate + N-way stratum assert (throws propagate)
      attributes = builtins.mapAttrs (_: eq: eq.compute) equations;
      eval = scope.eval { inherit roots attributes parseParent; }; # demand fixpoint (delegate)

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
            hash = null; # a reuse layer across evaluations is what would populate this
          };
        }) nodeIds
      );

      builtCtx = mkBuiltCtx eval accessor; # LAZY field, unforced on this path
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
        # The evaluator's attribute set, sealed alongside the equations it projects. It is here
        # because the warm fold is the PLANE's now and the plane is owed no equation record: what a
        # re-evaluation needs is the attribute functions, and deriving them inside the plane would
        # hand it a vocabulary that belongs to this library's authoring surface.
        attributes
        parseParent
        declaredEdges
        settings
        strataOrder
        ;
      schedule = sched; # carry the resolved schedule (edit-invariant)
    };
}
