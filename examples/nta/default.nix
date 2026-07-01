# §5.2 — the higher-order surface. A `cluster` node's `derived-children` NTA spawns one
# `service` node per replica MID-FOLD (Vogt 1989 §2): the node grammar grows during
# evaluation, each spawned node carries its own attributes, and gen-scope memoizes them.
{
  genResolve,
  genScope,
  lib,
}:
let
  inherit (genResolve)
    attr
    nta
    resolve
    project
    ;
  roots = genScope.buildNodes {
    decls.cluster = {
      replicas = 3;
      base = "svc";
    };
    types.cluster = "cluster";
  };
  eqs = {
    # empty children alongside derived-children (gen-scope resolveNode reads `children` unconditionally)
    children = nta {
      name = "children";
      spawn = self: id: { };
    };
    # spawn one service node per replica — the grammar grows here
    derived-children = nta {
      name = "derived-children";
      spawn =
        self: id:
        let
          node = self.node id;
          n = node.decls.replicas or 0;
        in
        if node.type == "cluster" then
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
                  type = "service";
                  parent = id;
                  decls.idx = i;
                };
              }
            ) (lib.range 0 (n - 1))
          )
        else
          { };
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
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent =
      id:
      if roots ? ${id} then
        (roots.${id}.parent or null)
      else
        let
          parts = lib.splitString "/" id;
        in
        if builtins.length parts > 1 then builtins.head parts else null;
  };

  allIds = lib.sort (a: b: a < b) (builtins.attrNames ctx.eval.allNodes);
  serviceIds = builtins.filter (i: i != "cluster") allIds;
  ports = map (i: project ctx i "port") serviceIds;

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
