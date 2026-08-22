# Cells whose `expr` can ABORT, and which therefore cannot live under `testModules`: the batch
# asserter behind `checks.default` forces every `expr` in `flake.tests` unconditionally, so an
# aborting one crashes that gate instead of failing a cell. Being on a separate output is what keeps
# that structural rather than conventional.
#
# WHAT IS ASSERTED HERE AND WHY IT NEEDED A SEPARATE HOME. The retired `edges` read a node's
# dependency list through `ctx.trace.<id> or { deps = [ ]; }`, so an id the fold never saw answered
# the EMPTY relation — the strongest claim available, awarded to a caller who asked about a node
# that does not exist. Its successor is the seal's own `trace.<id>.deps`, and that default does NOT
# travel: absence is a decision the caller makes and says. The cell below is the oracle for that
# delta, and it must live here because the successor's refusal is an UNCATCHABLE abort rather than a
# thrown value — `builtins.tryEval` does not catch `attribute 'x' missing` (measured, with `throw`
# catchable in the same run as the control), so a caught-throw cell for this behaviour cannot be
# written at all.
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve) attr _scheduleWith;
  inherit (genScope) foldEquations;

  flatKinds = names: genScope.mkKinds (map (name: genScope.mkKind { inherit name; }) names);

  roots = genScope.buildRoots {
    kinds = flatKinds [ "host" ];
    parentGraph = genScope.edge "a" "b";
    decls = {
      a.v = 1;
      b.v = 2;
    };
    types = {
      a = "host";
      b = "host";
    };
  };

  eqs = {
    self-v = attr {
      name = "self-v";
      kind = "synthesized";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.v;
    };
    imports = attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: [ ];
    };
  };

  ctx = foldEquations {
    scope = roots;
    declaredDependencies = id: if id == "a" then [ "b" ] else [ ];
    schedule = _scheduleWith { equations = eqs; };
    parseParent = id: roots.nodes.${id}.parent or null;
  };
in
{
  flake.testsError = {
    # ── THE DEFAULT DOES NOT TRAVEL ──
    # The successor refuses an id the fold never saw. A caller that wants the empty relation for an
    # unknown node now writes that decision down at its own call site.
    test-successor-refuses-an-unknown-node = {
      expr = ctx.trace."no-such-node".deps;
      expectedError = {
        type = "EvalError";
        msg = "attribute 'no-such-node' missing";
      };
    };

    # ── THE CONTROL, IN THE SAME FILE AND THE SAME RUN ──
    # A node the fold DID see answers its dependency list. Without this the cell above passes
    # against a seal whose trace is broken for every id, which is the same reading as a refusal
    # that discriminates.
    test-control-a-known-node-still-answers = {
      expr = ctx.trace."a".deps;
      expected = [ "b" ];
    };
  };
}
