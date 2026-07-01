# Task 8 — warmResolve batch. v1 shape is { edits } (the {id=newDecls} map), reconciling design §6's
# { changedIds }: a pure batch override must carry the data-change payload, which a bare id list cannot.
# One union reverse cone + one evalWarm (spliceAndWarm) == the chained override sequence == a fresh
# resolve with all edits pre-applied (byte-identical).
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    resolve
    override
    warmResolve
    project
    ;
  mkRoots =
    av: bv:
    genScope.buildNodes {
      decls = {
        a = {
          v = av;
        };
        b = {
          v = bv;
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
  pp = _: null;
  roots = mkRoots 1 2;
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent = pp;
  };
  edits = {
    a = {
      v = 5;
    };
    b = {
      v = 6;
    };
  };
  batch = warmResolve ctx { inherit edits; };
  probe = c: [
    (project c "a" "plus-one")
    (project c "b" "plus-one")
  ];
in
{
  flake.tests.warm-resolve = {
    # batch == the chained override sequence over the same edits (byte-identical)
    test-batch-eq-chained = {
      expr =
        let
          chained =
            override
              (override ctx {
                id = "a";
                newDecls = {
                  v = 5;
                };
              })
              {
                id = "b";
                newDecls = {
                  v = 6;
                };
              };
        in
        probe batch == probe chained;
      expected = true;
    };
    # batch == a fresh resolve with all edits pre-applied (single warm re-fold, structurally)
    test-batch-eq-fresh = {
      expr =
        let
          fresh = resolve {
            roots = mkRoots 5 6;
            equations = eqs;
            parseParent = pp;
          };
        in
        probe batch == probe fresh;
      expected = true;
    };
    test-batch-values = {
      expr = probe batch;
      expected = [
        6
        7
      ];
    };
    # edge-move anywhere in the batch throws (D14)
    test-batch-edge-move-throws = {
      expr =
        (builtins.tryEval (
          warmResolve ctx {
            edits = {
              a = {
                includes = [ "x" ];
              };
            };
          }
        )).success;
      expected = false;
    };
  };
}
