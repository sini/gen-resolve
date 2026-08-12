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
    # trackedAttrs (public _trackedAttrs) warm-serves the non-base strata under a custom order.
    test-resolve-nway-tracked-nonbase = {
      expr = builtins.sort builtins.lessThan (
        genResolve._trackedAttrs [ "structural" "resolution" "closure" ] {
          base = {
            stratum = "structural";
          };
          mid = {
            stratum = "resolution";
          };
          top = {
            stratum = "closure";
          };
          sink = {
            stratum = "terminal";
          };
        }
      );
      expected = [
        "mid"
        "sink"
        "top"
      ];
    };

    # ===== the builtCtx call sites, FORCED =====
    #
    # `builtCtx` is a LAZY ResolveCtx field: nothing on the cold or warm path forces it, so every
    # other cell in this repository passes whether or not the library supplying `build` supplies
    # anything at all. That was MEASURED, not assumed — the whole suite ran green, 69/69, against a
    # revision of that library with an EMPTY export surface. A suite that cannot tell a working
    # dependency from an absent one is not evidence about the dependency, so the two `build` call
    # sites are forced here and nowhere else.
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

    # And the hash is a real one. The per-node tracked attrset is `{ }` in this fixture — no
    # equation here sits in a tracked stratum — so a cell reading a stored VALUE would be asserting
    # emptiness and would pass against a store that returned nothing. The hash is computed over
    # whatever the node holds, so it is non-vacuous regardless.
    test-builtctx-cold-trace-hash-is-a-hash = {
      expr =
        let
          h = ctx.builtCtx.trace.child.hash;
        in
        builtins.isString h && builtins.stringLength h == 64;
      expected = true;
    };

    # The second call site: the override path builds a FRESH builtCtx over the overridden eval and
    # accessor. Forcing it covers the site the cold path never reaches.
    test-builtctx-override-forces-the-plane = {
      expr =
        let
          after = genResolve.override ctx {
            id = "child";
            newDecls = {
              v = 7;
            };
          };
        in
        builtins.sort builtins.lessThan (builtins.attrNames after.builtCtx.store);
      expected = [
        "child"
        "parent"
      ];
    };
  };
}
