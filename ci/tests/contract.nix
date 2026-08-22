{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    why
    _scheduleWith
    ;
  inherit (genScope) foldEquations;
  # A FLAT kind vocabulary: names, and no order between them, so no kind expands into another.
  # This fixture declares types and never spawns, which is exactly what an empty `below` says.
  flatKinds = names: genScope.mkKinds (map (name: genScope.mkKind { inherit name; }) names);
  roots = genScope.buildRoots {
    kinds = flatKinds [ "host" ];
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
  declaredDependencies = id: if id == "a" then [ "b" ] else [ ];
  ctx = foldEquations {
    scope = roots;
    inherit declaredDependencies;
    schedule = _scheduleWith { equations = eqs; };
    parseParent = id: roots.nodes.${id}.parent or null;
  };
in
{
  flake.tests.contract = {
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

    # ── THE RETIREMENT'S EDIT SHAPE, ARMED ──
    # `edges` left the export surface but stays as this module's internal binding, because `why` is
    # defined over it and what the binding carries beyond a field read is the `or { deps = [ ]; }`
    # default. An id the fold never saw answers the EMPTY relation here; the seal's own
    # `trace.<id>.deps` aborts for that case instead, uncatchably. This cell is what reds if a later
    # author reads the retirement as licence to point `why` at the successor — the migration would
    # look clean and would hand a live export an abort it never had.
    test-why-on-an-unknown-node-answers-empty = {
      expr = why ctx {
        id = "no-such-node";
        attr = "plus-one";
      };
      expected = [ ];
    };
  };
}
