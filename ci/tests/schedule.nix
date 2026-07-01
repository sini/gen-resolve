{ lib, genResolve, ... }:
let
  # minimal equation stubs (compute irrelevant to the schedule)
  eq = kind: reads: {
    inherit kind;
    readsAttrs = reads;
    stratum = "resolution";
    compute = self: id: null;
    name = "_";
  };
  build = genResolve._buildSchedule; # `_`-internal exposed by lib/default.nix (Task 0 Step 3)
in
{
  flake.tests.schedule = {
    test-acyclic-ok = {
      expr =
        (build {
          a = eq "synthesized" [ "b" ];
          b = eq "synthesized" [ ];
        }) ? attrGraph;
      expected = true;
    };
    # non-circular 2-cycle -> Knuth circularity test throws
    test-noncircular-scc-throws = {
      expr =
        (builtins.tryEval (build {
          a = eq "synthesized" [ "b" ];
          b = eq "synthesized" [ "a" ];
        })).success;
      expected = false;
    };
    # all-circular SCC converges (Sloane 2009 Kiama circular attributes)
    test-circular-scc-ok = {
      expr =
        (builtins.tryEval (build {
          a = eq "circular" [ "b" ];
          b = eq "circular" [ "a" ];
        })).success;
      expected = true;
    };
    # self-loop non-circular throws
    test-selfloop-throws = {
      expr =
        (builtins.tryEval (build {
          a = eq "synthesized" [ "a" ];
        })).success;
      expected = false;
    };
  };
}
