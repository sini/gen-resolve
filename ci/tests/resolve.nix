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
    # demanded leaf value flows from decls (project == eval.get)
    test-project-leaf = {
      expr = ctx.eval.get "child" "self-v";
      expected = 1;
    };
    # derived attr reads another attr through the demand fixpoint
    test-project-derived = {
      expr = ctx.eval.get "parent" "plus-one";
      expected = 11;
    };
    # The sealed context, asserted as an EXACT SET rather than as presence.
    #
    # WHY THE FORM CHANGED. This cell was `builtins.all (k: ctx ? ${k}) [ …ten names… ]` — a presence
    # check, satisfied by any context containing those ten and silent about everything else. The
    # context grew to eleven when `strataOrder` was added and to twelve when the warm fold's
    # departure put `attributes` on it, and the cell passed unchanged through both: a sealed-surface
    # test that under-enumerates its surface passes while the seal is broken. Three prose sites
    # drifted behind it for exactly that reason — nothing ever reddened.
    #
    # Compared on NAMES. `attrNames` returns them sorted, so a widening, a narrowing, or a rename
    # all fail this cell, which is the arming the sibling plane's export pin already had.
    test-ctx-sealed = {
      expr = builtins.attrNames ctx;
      expected = [
        "accessor"
        "attributes"
        "builtCtx"
        "declaredEdges"
        "equations"
        "eval"
        "parseParent"
        "roots"
        "schedule"
        "settings"
        "strataOrder"
        "trace"
      ];
    };
    # builtCtx is lazy — a resolve with a CYCLIC declaredEdges would make the plane's node-cycle
    # check throw IF builtCtx were forced; cold resolve + project must still succeed.
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
    # resolve threads a custom strataOrder → the N-way assert fires at resolve time (schedule seq-forced).
    test-resolve-nway-violation-throws = {
      expr =
        (builtins.tryEval (
          genResolve.resolve {
            roots = [ ];
            parseParent = _: null;
            strataOrder = [
              "structural"
              "resolution"
              "closure"
            ];
            equations = {
              early = genResolve.attr {
                name = "early";
                kind = "synthesized";
                stratum = "resolution";
                readsAttrs = [ "late" ];
                compute = self: id: null;
              };
              late = genResolve.attr {
                name = "late";
                kind = "synthesized";
                stratum = "closure";
                readsAttrs = [ ];
                compute = self: id: null;
              };
            };
          }
        )).success;
      expected = false;
    };
    # ===== the builtCtx call site, FORCED =====
    #
    # `builtCtx` is a LAZY ResolveCtx field: nothing on the cold path forces it, so every other cell
    # in this repository passes whether or not the library supplying `build` supplies anything at
    # all. That was MEASURED, not assumed — the whole suite ran green, 69/69, against a revision of
    # that library with an EMPTY export surface. A suite that cannot tell a working dependency from
    # an absent one is not evidence about the dependency, so the `build` call site is forced here and
    # nowhere else.
    #
    # There USED to be two such sites; the second was the warm fold's, and the warm fold has moved to
    # the plane. The forcing cell moved with it rather than being dropped.
    #
    # Forced through `.store` and `.trace` rather than through the field's presence: the field is an
    # attrset that exists whatever `build` returned, so asserting it is there would rebuild the same
    # blindness one level down.
    test-builtctx-cold-store-forces-the-plane = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames ctx.builtCtx.store);
      expected = [
        "child"
        "parent"
      ];
    };

    # The verifying trace arrives with the store: per key, the declared deps and a content hash.
    test-builtctx-cold-trace-shape = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames ctx.builtCtx.trace.child);
      expected = [
        "deps"
        "hash"
      ];
    };

    # And the hash is a real one, computed over whatever the node holds.
    test-builtctx-cold-trace-hash-is-a-hash = {
      expr =
        let
          h = ctx.builtCtx.trace.child.hash;
        in
        builtins.isString h && builtins.stringLength h == 64;
      expected = true;
    };

    # The stored value itself, which this cell can now assert because there IS one. Under the
    # declared-stratum filter this projection was `{ }` for this fixture — every equation here sits
    # in the base stratum — so the cell above carried a note that a value assertion would be
    # asserting emptiness. The projection is now the evaluator's resolutional vocabulary, and BOTH
    # directions are visible in one expectation: `children` is inside the reserved structural
    # namespace and is absent, the other three are outside it and are present. A projection that
    # took everything, and one that took nothing, each fail this cell.
    test-builtctx-cold-store-projects-resolutional = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames ctx.builtCtx.store.child);
      expected = [
        "imports"
        "plus-one"
        "self-v"
      ];
    };
  };
}
