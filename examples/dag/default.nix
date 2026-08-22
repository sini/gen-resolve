# §5.1 — the abstract attribute-DAG surface. A neron `cascade` channel folds layered
# settings least-specific-first (default < env < host < policy, LAST wins), and the static
# schedule rejects a non-convergent cycle and a two-stratum partition violation.
{
  genResolve,
  genScope,
}:
let
  inherit (genResolve)
    attr
    cascade
    ;
  inherit (genScope) foldEquations;
  build = genResolve._buildSchedule;

  # scope hierarchy policy -> host -> env -> default: each node's PARENT is the next-broader
  # scope (default is the root ancestor, policy the most-specific leaf). The neron traversal
  # walks self -> direct imports -> up the parent chain, so the cascade collects every layer.
  roots = genScope.buildRoots {
    # A FLAT kind vocabulary: names, and no order between them, so no kind expands into another.
    # This example declares types and never spawns, which is exactly what an empty `below` says.
    kinds = genScope.mkKinds [ (genScope.mkKind { name = "host"; }) ];
    parentGraph = genScope.path [
      "policy"
      "host"
      "env"
      "default"
    ];
    decls = {
      policy.settings = {
        x = "policy";
      };
      host.settings = {
        x = "host";
        y = "host-y";
      };
      env.settings = {
        x = "env";
      };
      default.settings = {
        x = "default";
        z = "default-z";
      };
    };
    types = {
      policy = "host";
      host = "host";
      env = "host";
      default = "host";
    };
  };

  eqs = {
    imports = attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.__edges.I or [ ];
    };
    settings = cascade {
      name = "settings";
      channel = "settings";
    };
  };
  ctx = foldEquations {
    scope = roots;
    # Stated rather than defaulted: the layering here is the parent chain, which the structural
    # half of the union already carries; no read-edge is declared at the node level.
    declaredDependencies = _: [ ];
    schedule = genResolve._scheduleWith { equations = eqs; };
    parseParent = id: roots.nodes.${id}.parent or null;
  };
  resolved = ctx.eval.facade.get "policy" "settings";

  # stub equations for the two schedule gates
  eq = kind: reads: stratum: {
    inherit kind stratum;
    readsAttrs = reads;
    compute = self: id: null;
    name = "_";
  };
  noncircularThrows =
    !(builtins.tryEval (build {
      a = eq "synthesized" [ "b" ] "resolution";
      b = eq "synthesized" [ "a" ] "resolution";
    })).success;
  stratumThrows =
    !(builtins.tryEval (build {
      imports = eq "synthesized" [ "resolved-aspects" ] "structural";
      resolved-aspects = eq "circular" [ ] "resolution";
    })).success;

  checks = {
    cascade-policy-wins = resolved.x == "policy"; # most-specific layer wins
    cascade-inherits-host = resolved.y == "host-y"; # a mid layer's field survives
    cascade-inherits-default = resolved.z == "default-z"; # least-specific field survives
    noncircular-scc-throws = noncircularThrows; # Knuth 1968 circularity test
    stratum-violation-throws = stratumThrows; # van Antwerpen 2016 §4.3
  };
in
{
  inherit resolved checks;
  ok = builtins.all (v: v) (builtins.attrValues checks);
}
