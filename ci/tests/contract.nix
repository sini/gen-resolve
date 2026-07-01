{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    resolve
    project
    edges
    why
    ;
  roots = genScope.buildNodes {
    parentGraph = genScope.edge "a" "b";
    decls = {
      a = {
        v = 1;
      };
      b = {
        v = 2;
      };
    };
    types = {
      a = "host";
      b = "host";
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
    imports = genResolve.attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: [ ];
    };
  };
  # `a` declares a read-edge to `b` (consumer -> producer)
  declaredEdges = id: if id == "a" then [ "b" ] else [ ];
  ctx = resolve {
    inherit roots declaredEdges;
    equations = eqs;
    parseParent = id: roots.${id}.parent or null;
  };
in
{
  flake.tests.contract = {
    # project == eval.get (no class-content forcing)
    test-project = {
      expr = project ctx "a" "plus-one";
      expected = 2;
    };
    # edges == the declared read-edges (trace.<id>.deps)
    test-edges = {
      expr = edges ctx "a";
      expected = [ "b" ];
    };
    test-edges-empty = {
      expr = edges ctx "b";
      expected = [ ];
    };
    # why == NAME-only static provenance: declared node-edges x readsAttrs
    test-why = {
      expr = why ctx {
        id = "a";
        attr = "plus-one";
      };
      expected = [
        {
          id = "b";
          attr = "self-v";
        }
      ];
    };
  };
}
