{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve) resolve override project;
  mkRoots =
    cv:
    genScope.buildNodes {
      parentGraph = genScope.edge "child" "parent";
      decls = {
        parent = {
          v = 10;
        };
        child = {
          v = cv;
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
    imports = genResolve.attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: [ ];
    };
  };
  pp = roots: id: roots.${id}.parent or null;
  roots = mkRoots 1;
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent = pp roots;
  };
in
{
  flake.tests.override = {
    # byte-identical (RTD 1983): override == a fresh resolve with the decl pre-applied
    test-override-byte-identical = {
      expr =
        let
          ctx' = override ctx {
            id = "child";
            newDecls = {
              v = 5;
            };
          };
          fresh = resolve {
            roots = mkRoots 5;
            equations = eqs;
            parseParent = pp (mkRoots 5);
          };
        in
        project ctx' "child" "plus-one" == project fresh "child" "plus-one";
      expected = true;
    };
    # the changed node re-derives to the new decl (cone recomputed)
    test-override-new-value = {
      expr = project (override ctx {
        id = "child";
        newDecls = {
          v = 5;
        };
      }) "child" "plus-one";
      expected = 6;
    };
    # a node outside the changed node's reverse cone keeps its prior value (warm-served)
    test-noncone-kept = {
      expr = project (override ctx {
        id = "child";
        newDecls = {
          v = 5;
        };
      }) "parent" "plus-one";
      expected = 11;
    };
    # edge-move (topology change) errors in v1 (D14)
    test-edge-move-throws = {
      expr =
        (builtins.tryEval (
          override ctx {
            id = "child";
            newDecls = {
              includes = [ "other" ];
            };
          }
        )).success;
      expected = false;
    };
    # DP4: override works on a CYCLIC node graph — dependentsOf is cycle-safe and builtCtx is never
    # forced, so gen-rebuild's node-cycle check never trips. Data-change resolves byte-identically.
    test-cyclic-override-ok = {
      expr =
        let
          cyclicEdges = id: if id == "child" then [ "parent" ] else [ "child" ]; # parent <-> child
          cctx = resolve {
            inherit roots;
            equations = eqs;
            parseParent = pp roots;
            declaredEdges = cyclicEdges;
          };
          cctx' = override cctx {
            id = "child";
            newDecls = {
              v = 7;
            };
          };
        in
        project cctx' "child" "plus-one";
      expected = 8;
    };
  };
}
