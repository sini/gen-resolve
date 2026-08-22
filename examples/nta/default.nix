# §5.2 — the higher-order surface. A `cluster` node's `derived-children` NTA spawns one
# `service` node per replica MID-FOLD (Vogt 1989 §2): the node grammar grows during
# evaluation and each spawned node carries its own attributes. (gen-scope memoizes the `get`
# cache internally, but that is not observable via pure-value equality, so it is not asserted.)
{
  genResolve,
  genScope,
  lib,
}:
let
  inherit (genResolve)
    attr
    nta
    ;
  inherit (genScope) foldEquations;
  # THE EXPANSION IS DECLARED ON THE KIND IT EXPANDS FROM. `cluster` registers `service` in its
  # `below` and names the builder under that key, so the produced kind is a registered name below
  # its host's own and the descent is settled before anything fires. The builder does not choose
  # its child's kind — the substrate stamps it from the key it was declared under — so no `type`
  # field is written here.
  roots = genScope.buildRoots {
    kinds = genScope.mkKinds [
      (genScope.mkKind { name = "service"; })
      (genScope.mkKind {
        name = "cluster";
        below = [ "service" ];
        spawns.service =
          ev: id:
          let
            node = ev.node id;
            n = node.decls.replicas or 0;
          in
          lib.listToAttrs (
            map (
              i:
              let
                cid = "${id}/${node.decls.base}-${toString i}";
              in
              {
                name = cid;
                value = {
                  id = cid;
                  parent = id;
                  decls.idx = i;
                };
              }
            ) (lib.range 0 (n - 1))
          );
      })
    ];
    decls.cluster = {
      replicas = 3;
      base = "svc";
    };
    types.cluster = "cluster";
  };
  eqs = {
    # empty children alongside the spawn channel (gen-scope resolveNode reads `children` unconditionally)
    children = nta {
      name = "children";
      spawn = self: id: { };
    };
    # a per-service attribute (each spawned node computes its own port)
    port = attr {
      name = "port";
      kind = "synthesized";
      readsAttrs = [ ];
      compute = self: id: 8080 + ((self.node id).decls.idx or 0);
    };
    imports = attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: [ ];
    };
  };
  ctx = foldEquations {
    scope = roots;
    declaredDependencies = _: [ ];
    schedule = genResolve._scheduleWith { equations = eqs; };
    parseParent =
      id:
      if roots.nodes ? ${id} then
        (roots.nodes.${id}.parent or null)
      else
        let
          parts = lib.splitString "/" id;
        in
        if builtins.length parts > 1 then builtins.head parts else null;
  };

  allIds = lib.sort (a: b: a < b) (builtins.attrNames ctx.eval.allNodes);
  serviceIds = builtins.filter (i: i != "cluster") allIds;
  ports = map (i: ctx.eval.facade.get i "port") serviceIds;

  checks = {
    grammar-grew = builtins.length allIds == 4; # cluster + 3 spawned services
    services-spawned =
      serviceIds == [
        "cluster/svc-0"
        "cluster/svc-1"
        "cluster/svc-2"
      ];
    per-service-attrs =
      ports == [
        8080
        8081
        8082
      ];
    # each spawned node is a real, typed grammar node reachable through the fold
    spawned-nodes-typed = builtins.all (i: (ctx.eval.node i).type == "service") serviceIds;
  };
in
{
  inherit serviceIds ports checks;
  ok = builtins.all (v: v) (builtins.attrValues checks);
}
