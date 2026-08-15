# THE STANDALONE ENTRY, EXERCISED. `import ../.. { }` is the non-flake path this repository
# documents — `ci/repl.nix` builds its surface with it, and a consumer with no flake has nothing
# else. Every OTHER cell in this suite takes `genResolve` from `ci/flake.nix`, which imports
# `../lib` directly and so never evaluates the root shim: a shim that names a sibling's private
# formals can therefore be wrong in every release without one cell noticing. This is that cell.
#
# One cell, one key per sibling the shim CONSTRUCTS, because each key forces exactly that one:
#   scope — `reference`'s `compute` IS `scope.query { … }`, produced when the equation is built
#   graph — a schedule's circularity test is `graph.condensation` over the attr-dep edges
#   bind  — `terminalBind` is `bind.wrapAll`, which needs no resolution context to force
# `algebra` is deliberately not forced. It is reached only from inside a `cascade` compute, which
# needs a resolution context, and it is a dependency the shim takes as a bare value rather than
# constructing — there is no arity contract there to get wrong.
#
# WHY THE KEYS FORCE VALUES. Each key is a POSITIVE assertion that the shim constructs its sibling,
# and forcing is how a construction is observed — not a stand-in for a missing comparison. The
# negative forms cannot be used here, because every one of them passes in the broken shape:
# `(builtins.tryEval …).success` reads `true`, an arity abort being an evaluator error `tryEval`
# does not contain, and `deepSeq` or `attrNames` over the surface never enter the lambdas where the
# siblings are reached.
#
# A broken shim fails both instruments. `nix flake check` — the merge gate — reaches these
# assertions through `checks.default` and fails on a wrong value as well as on an abort. `nix-unit`
# isolates the break to one poisoned cell, reported ☢️ with a non-zero exit and NO red ❌, so a
# reading of THAT instrument which tallies only ❌ scores the break green.
{ ... }:
let
  entry = import ../.. { };
  eq = kind: reads: {
    inherit kind;
    readsAttrs = reads;
    stratum = "resolution";
    compute = self: id: null;
    name = "_";
  };
in
{
  flake.tests.entry.test-standalone-entry-constructs-its-siblings = {
    expr = {
      scope =
        builtins.isFunction
          (entry.reference {
            name = "r";
            select = _: true;
          }).compute;
      graph =
        (entry._buildSchedule {
          a = eq "synthesized" [ "b" ];
          b = eq "synthesized" [ ];
        }) ? attrGraph;
      bind = builtins.isList (
        entry.terminalBind {
          modules = [ ({ host, config, ... }: { }) ];
          bindings = {
            host = { };
          };
        }
      );
    };
    expected = {
      scope = true;
      graph = true;
      bind = true;
    };
  };
}
