# THE PLANE'S BUILD, FORCED — the only site in this ecosystem that forces `memo.build`.
#
# The cold fold's own cells left with the fold. What did NOT leave with it is the memo context it
# used to build: constructing that inside the evaluator would install the incremental plane inside
# the thing the plane is defined against. So the context is composed HERE instead, by a caller
# holding both libraries — which is the direction ADR-0008 §2 already runs, the plane reading the
# evaluator's accessor.
#
# WHY THE FORCING IS HERE AND NOWHERE ELSE. The built context is a lazy value nothing on the cold
# path forces, so every other cell in this repository passes whether or not the library supplying
# `build` supplies anything at all. That was MEASURED, not assumed — the whole suite once ran green
# against a revision of that library with an EMPTY export surface. A suite that cannot tell a working
# dependency from an absent one is not evidence about the dependency.
#
# Forced through `.store` and `.trace` rather than through the value's presence: what `build` returns
# is an attrset whatever it did, so asserting the field is there would rebuild the same blindness one
# level down.
{
  lib,
  genResolve,
  genScope,
  genMemo,
  ...
}:
let
  inherit (genResolve) _scheduleWith;
  inherit (genScope) foldEquations;
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
  ctx = foldEquations {
    inherit roots;
    schedule = _scheduleWith { equations = eqs; };
    parseParent = id: roots.${id}.parent or null;
  };

  # The plane's memo context over this evaluation's own accessor. Its recompute reads its OWN paired
  # evaluation, so the hashes describe that evaluation and no other.
  #
  # THE PROJECTION IS READ OFF THE EVALUATOR AND IS NOT COMPUTED HERE. What may be reused is the
  # evaluator's own resolutional vocabulary — its attribute names minus the structural partition —
  # which it publishes per node. Deciding the same question from a DECLARED stratum is how a second
  # answer in a second library comes to disagree with the first.
  builtCtx = genMemo.build {
    inherit (ctx) accessor;
    recompute =
      _acc: _store: id:
      builtins.listToAttrs (
        map (a: {
          name = a;
          value = ctx.eval.get id a;
        }) (ctx.eval.resolutional id)
      );
    hashOf = v: builtins.hashString "sha256" (builtins.toJSON v); # function-bearing -> the plane nulls the hash -> always-dirty
  };
in
{
  flake.tests.resolve = {
    test-builtctx-cold-store-forces-the-plane = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames builtCtx.store);
      expected = [
        "child"
        "parent"
      ];
    };

    # The verifying trace arrives with the store: per key, the declared deps and a content hash.
    test-builtctx-cold-trace-shape = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames builtCtx.trace.child);
      expected = [
        "deps"
        "hash"
      ];
    };

    # And the hash is a real one, computed over whatever the node holds.
    test-builtctx-cold-trace-hash-is-a-hash = {
      expr =
        let
          h = builtCtx.trace.child.hash;
        in
        builtins.isString h && builtins.stringLength h == 64;
      expected = true;
    };

    # The stored value itself, which this cell can assert because there IS one. The projection is the
    # evaluator's resolutional vocabulary, and BOTH directions are visible in one expectation:
    # `children` is inside the reserved structural namespace and is absent, the other three are
    # outside it and are present. A projection that took everything, and one that took nothing, each
    # fail this cell.
    test-builtctx-cold-store-projects-resolutional = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames builtCtx.store.child);
      expected = [
        "imports"
        "plus-one"
        "self-v"
      ];
    };
  };
}
