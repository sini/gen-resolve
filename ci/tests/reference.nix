# reference `target` is a REAL direction selector: "includes" (forward, Hedin 2000 nearest
# binding) vs "neededBy" (reverse, Hedin & Magnusson 2003 — gather over the nodes that import
# me, delegated to gen-scope.queryReverse). web1/web2 import db1.
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    attr
    reference
    resolve
    project
    ;
  roots = genScope.buildNodes {
    importGraph = genScope.overlays [
      (genScope.edge "web1" "db1")
      (genScope.edge "web2" "db1")
    ];
    decls = {
      db1.role = "database";
      web1.tag = "w1";
      web2.tag = "w2";
    };
    types = {
      db1 = "host";
      web1 = "host";
      web2 = "host";
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
    # forward: a web node dereferences db1's role across its includes edge
    db-role = reference {
      name = "db-role";
      select = n: n.decls.role or null;
      target = "includes";
    };
    # reverse: db1 gathers the tag of every node that imports it (neededBy)
    consumers = reference {
      name = "consumers";
      select = n: n.decls.tag or null;
      target = "neededBy";
    };
  };
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent = _: null;
  };
in
{
  flake.tests.reference = {
    # forward includes: web1 dereferences db1's role
    test-includes-forward = {
      expr = project ctx "web1" "db-role";
      expected = "database";
    };
    # reverse neededBy: db1 gathers its importers' tags (the delegated queryReverse)
    test-neededBy-reverse = {
      expr = builtins.sort builtins.lessThan (project ctx "db1" "consumers");
      expected = [
        "w1"
        "w2"
      ];
    };
    # a leaf importer with no importers has an empty reverse set
    test-neededBy-empty = {
      expr = project ctx "web1" "consumers";
      expected = [ ];
    };
    # an invalid target is rejected at registration
    test-invalid-target-throws = {
      expr =
        (builtins.tryEval (reference {
          name = "x";
          select = _: null;
          target = "sideways";
        })).success;
      expected = false;
    };
  };
}
