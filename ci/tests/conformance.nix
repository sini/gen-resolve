# Task 10 — the theory oracle. Each property cites the lemma it discharges:
#   1. demand-order == from-scratch toposort            Knuth 1968 (attribute schedule)
#   2. well-definedness gate throws                      Knuth 1968 circularity test / Vogt 1989
#   3. two-stratum partition assert throws               van Antwerpen 2016 §4.3
#   4. NTA grammar-growth (a typed node appears mid-fold)  Vogt 1989 §2 (higher-order AG)
#   5. override byte-identical to pre-applied resolve     RTD 1983 SOUNDNESS (not minimality: the
#                                                          O(|AFFECTED|) optimality is deferred, v1 recomputes the cone)
#
# DAGs are derived from integer seeds (no Math.random): a_i reads a_j (j<i) iff (seed+7i+3j) mod 3 != 0,
# so every generated attribute grammar is acyclic by construction and varies with the seed.
{
  lib,
  genResolve,
  genScope,
  genGraph,
  ...
}:
let
  inherit (genResolve)
    resolve
    override
    project
    attr
    nta
    ;
  build = genResolve._buildSchedule;

  modp = a: b: a - b * (a / b);
  range = n: builtins.genList (x: x) n; # [0 .. n-1]
  aName = i: "a${toString i}";
  n = 8;
  idxOf = builtins.listToAttrs (
    map (i: {
      name = aName i;
      value = i;
    }) (range n)
  );
  # deterministic acyclic attribute-DAG: reads are a strict subset of the lower indices
  readsOf = seed: i: builtins.filter (j: modp (seed + 7 * i + 3 * j) 3 != 0) (range i);

  # a_i = i + (base at a_0) + sum of the values it reads  (base flows from a_0 up the DAG)
  eqsFor =
    seed:
    builtins.listToAttrs (
      map (i: {
        name = aName i;
        value = attr {
          name = aName i;
          kind = "synthesized";
          readsAttrs = map aName (readsOf seed i);
          compute =
            self: id:
            i
            + (if i == 0 then (self.node id).decls.base else 0)
            + builtins.foldl' (acc: j: acc + self.get id (aName j)) 0 (readsOf seed i);
        };
      }) (range n)
    );
  rootsFor =
    v:
    genScope.buildNodes {
      decls.node = {
        base = v;
      };
      types.node = "host";
    };
  ctxFor =
    seed: base:
    resolve {
      roots = rootsFor base;
      equations = eqsFor seed;
      parseParent = _: null;
    };

  # from-scratch topological reference: fold in gen-graph's coneRank order (producers-first)
  refStore =
    seed: base:
    let
      names = map aName (range n);
      accessor.edges = a: map aName (readsOf seed idxOf.${a});
      order = (genGraph.coneRank accessor names).order;
    in
    builtins.foldl' (
      s: a:
      let
        i = idxOf.${a};
      in
      s
      // {
        ${a} =
          i + (if i == 0 then base else 0) + builtins.foldl' (acc: j: acc + s.${aName j}) 0 (readsOf seed i);
      }
    ) { } order;

  seeds = [
    1
    2
    3
    4
    5
  ];

  # (1) demand-order values == the strict topological reference, over every seeded DAG
  demandEqToposort = builtins.all (
    seed:
    let
      ctx = ctxFor seed 0;
      ref = refStore seed 0;
    in
    builtins.all (i: project ctx "node" (aName i) == ref.${aName i}) (range n)
  ) seeds;

  # (5) override == fresh resolve with the decl pre-applied, over every seeded DAG
  overrideByteIdentical = builtins.all (
    seed:
    let
      eqs = eqsFor seed;
      ctx = resolve {
        roots = rootsFor 3;
        equations = eqs;
        parseParent = _: null;
      };
      ctx' = override ctx {
        id = "node";
        newDecls = {
          base = 9;
        };
      };
      fresh = resolve {
        roots = rootsFor 9;
        equations = eqs;
        parseParent = _: null;
      };
    in
    builtins.all (i: project ctx' "node" (aName i) == project fresh "node" (aName i)) (range n)
  ) seeds;

  # (2)/(3) schedule gates — minimal stub equations
  stubEq = kind: reads: stratum: {
    inherit kind stratum;
    readsAttrs = reads;
    compute = self: id: null;
    name = "_";
  };
  wfGateThrows =
    !(builtins.tryEval (build {
      a = stubEq "synthesized" [ "b" ] "resolution";
      b = stubEq "synthesized" [ "a" ] "resolution";
    })).success
    && (builtins.tryEval (build {
      a = stubEq "circular" [ "b" ] "resolution";
      b = stubEq "circular" [ "a" ] "resolution";
    })).success;
  stratumAssertThrows =
    !(builtins.tryEval (build {
      imports = stubEq "synthesized" [ "resolved-aspects" ] "structural";
      resolved-aspects = stubEq "circular" [ ] "resolution";
    })).success;

  # (4) NTA grammar-growth: derived-children spawns a node NOT in roots; its attr resolves through the fold
  ntaRoots = genScope.buildNodes {
    decls.p = {
      seedN = 5;
    };
    types.p = "host";
  };
  ntaEqs = {
    # empty `children` alongside `derived-children`: gen-scope's non-root resolveNode reads
    # `get parent "children"` unconditionally (unlike the guarded _walkFrom), so it must exist.
    children = nta {
      name = "children";
      spawn = self: id: { };
    };
    derived-children = nta {
      name = "derived-children";
      spawn =
        self: id:
        let
          node = self.node id;
        in
        if node.type == "host" then
          {
            "${id}-child" = {
              id = "${id}-child";
              type = "spawned";
              parent = id;
              decls.v = (node.decls.seedN or 0) + 1;
            };
          }
        else
          { };
    };
    val = attr {
      name = "val";
      kind = "synthesized";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.v or (self.node id).decls.seedN or 0;
    };
    imports = attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: [ ];
    };
  };
  ntaCtx = resolve {
    roots = ntaRoots;
    equations = ntaEqs;
    parseParent =
      id:
      if ntaRoots ? ${id} then
        (ntaRoots.${id}.parent or null)
      else
        let
          parts = lib.splitString "-child" id;
        in
        if builtins.length parts > 1 then builtins.head parts else null;
  };
  # NOTE: memoization is a gen-scope internal (the `get` cache) and is NOT observable through
  # pure-value equality — `project x == project x` is a tautology that proves nothing, so it is
  # deliberately omitted. This exercises grammar GROWTH: a real, typed node appears mid-fold and
  # its attribute resolves through the demand fixpoint.
  ntaGrew =
    (ntaCtx.eval.allNodes ? "p-child") # grammar grew mid-fold (Vogt 1989 §2)
    && ((ntaCtx.eval.node "p-child").type == "spawned") # the spawned node is a real, typed grammar node
    && (project ntaCtx "p-child" "val" == 6); # its attribute resolves through the fold
in
{
  flake.tests.conformance = {
    # Knuth 1968 — demand (Nix laziness) computes the same values a strict topological schedule would
    test-demand-order-eq-toposort = {
      expr = demandEqToposort;
      expected = true;
    };
    # Knuth 1968 circularity / Vogt 1989 — non-circular SCC rejected, all-circular SCC accepted
    test-wf-gate-throws = {
      expr = wfGateThrows;
      expected = true;
    };
    # van Antwerpen 2016 §4.3 — a structural attr reaching a resolution attr is rejected
    test-stratum-assert-throws = {
      expr = stratumAssertThrows;
      expected = true;
    };
    # Vogt 1989 §2 — higher-order NTA grows the node grammar mid-fold (a real typed node appears)
    test-nta-grammar-growth = {
      expr = ntaGrew;
      expected = true;
    };
    # RTD 1983 SOUNDNESS — incremental override == from-scratch resolve (byte-identical). This tests
    # correctness, NOT RTD's O(|AFFECTED|) minimality (deferred; v1 recomputes the whole reverse cone).
    test-override-byte-identical = {
      expr = overrideByteIdentical;
      expected = true;
    };
  };
}
