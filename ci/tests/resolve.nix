{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve) resolve;
  roots = genScope.buildNodes {
    parentGraph = genScope.edge "child" "parent";
    decls = {
      parent = {
        v = 10;
      };
      child = {
        v = 1;
      };
    };
    types = {
      parent = "host";
      child = "host";
    };
  };
  eqs = {
    self-v = genResolve.attr {
      name = "self-v";
      kind = "synthesized";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.v;
    };
    plus-one = genResolve.attr {
      name = "plus-one";
      kind = "synthesized";
      readsAttrs = [ "self-v" ];
      compute = self: id: self.get id "self-v" + 1;
    };
    children = genResolve.nta {
      name = "children";
      spawn = self: id: lib.filterAttrs (_: n: n.parent == id) roots;
    };
    imports = genResolve.attr {
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
    parseParent = id: roots.${id}.parent or null;
  };
in
{
  flake.tests.resolve = {
    # demanded leaf value flows from decls (project == eval.get; project itself is Task 5)
    test-project-leaf = {
      expr = ctx.eval.get "child" "self-v";
      expected = 1;
    };
    # derived attr reads another attr through the demand fixpoint
    test-project-derived = {
      expr = ctx.eval.get "parent" "plus-one";
      expected = 11;
    };
    # sealed 10-field ResolveCtx (design §3)
    test-ctx-sealed = {
      expr = builtins.all (k: ctx ? ${k}) [
        "eval"
        "accessor"
        "builtCtx"
        "schedule"
        "trace"
        "roots"
        "equations"
        "parseParent"
        "declaredEdges"
        "settings"
      ];
      expected = true;
    };
    # DP4: builtCtx lazy — a resolve with a CYCLIC declaredEdges would make gen-rebuild.build's
    # node-cycle check throw IF builtCtx were forced; cold resolve + project must still succeed.
    test-cold-ignores-builtctx = {
      expr =
        let
          cyclic = resolve {
            inherit roots;
            equations = eqs;
            parseParent = id: roots.${id}.parent or null;
            declaredEdges = id: if id == "child" then [ "parent" ] else [ "child" ];
          };
        in
        cyclic.eval.get "child" "self-v";
      expected = 1;
    };
  };
}
