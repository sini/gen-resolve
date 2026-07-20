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
  buildN = genResolve._scheduleWith; # `_`-internal exposed by lib/default.nix (this task)
  eqAt = kind: reads: stratum: {
    inherit kind stratum;
    readsAttrs = reads;
    compute = self: id: null;
    name = "_";
  };
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
    # structural imports reaching resolution resolved-aspects -> van Antwerpen violation, throws
    test-stratum-violation-throws = {
      expr =
        (builtins.tryEval (build {
          imports = (eq "synthesized" [ "resolved-aspects" ]) // {
            stratum = "structural";
          };
          resolved-aspects = (eq "circular" [ ]) // {
            stratum = "resolution";
          };
        })).success;
      expected = false;
    };
    # terminal output-modules reading resolution is fine (sink exempt)
    test-terminal-reads-resolution-ok = {
      expr =
        (builtins.tryEval (build {
          output-modules = (eq "synthesized" [ "resolved-aspects" ]) // {
            stratum = "terminal";
          };
          resolved-aspects = (eq "circular" [ ]) // {
            stratum = "resolution";
          };
        })).success;
      expected = true;
    };
    # MIXED SCC (one circular + one non-circular member) -> Vogt gate throws. Exercises the
    # `all (isCircular) scc` quantifier that all-synth / all-circular alone never hit.
    test-mixed-scc-throws = {
      expr =
        (builtins.tryEval (build {
          a = eq "circular" [ "b" ];
          b = eq "synthesized" [ "a" ];
        })).success;
      expected = false;
    };
    # den `enriched-context` shape (M1): a `circular` attr carrying an EXPLICIT `structural`
    # stratum, read by structural graph-builders. stratumOf honors explicit for any kind, so the
    # structural cone reaches no resolution attr and the self-referential SCC is all-circular ->
    # the grammar builds. (A future "conform stratumOf to synthesized-only" refactor would break this.)
    test-circular-structural-den-shape = {
      expr =
        (builtins.tryEval (build {
          imports = (eq "synthesized" [ "enriched-context" ]) // {
            stratum = "structural";
          };
          enriched-context = (eq "circular" [ "enriched-context" ]) // {
            stratum = "structural";
          };
        })).success;
      expected = true;
    };
    test-nway-later-reads-earlier-ok = {
      expr =
        (builtins.tryEval (buildN {
          strataOrder = [
            "structural"
            "resolution"
            "closure"
          ];
          equations = {
            reach = eqAt "synthesized" [ "rel" ] "closure";
            rel = eqAt "synthesized" [ ] "resolution";
          };
        })).success;
      expected = true;
    };
    test-nway-earlier-reads-later-throws = {
      expr =
        (builtins.tryEval (buildN {
          strataOrder = [
            "structural"
            "resolution"
            "closure"
          ];
          equations = {
            rel = eqAt "synthesized" [ "reach" ] "resolution";
            reach = eqAt "synthesized" [ ] "closure";
          };
        })).success;
      expected = false;
    };
    test-nway-unknown-stratum-throws = {
      expr =
        (builtins.tryEval (buildN {
          strataOrder = [
            "structural"
            "resolution"
          ];
          equations = {
            a = eqAt "synthesized" [ ] "bogus";
          };
        })).success;
      expected = false;
    };
    test-nway-terminal-exempt = {
      expr =
        (builtins.tryEval (buildN {
          strataOrder = [
            "structural"
            "resolution"
            "closure"
          ];
          equations = {
            out = eqAt "synthesized" [ "reach" ] "terminal";
            reach = eqAt "synthesized" [ ] "closure";
          };
        })).success;
      expected = true;
    };
    # multi-hop: structural reaches closure via resolution (2-hop cone) → violation surfaces transitively.
    test-nway-multihop-cone-throws = {
      expr =
        (builtins.tryEval (buildN {
          strataOrder = [
            "structural"
            "resolution"
            "closure"
          ];
          equations = {
            a = eqAt "synthesized" [ "b" ] "structural";
            b = eqAt "synthesized" [ "c" ] "resolution";
            c = eqAt "synthesized" [ ] "closure";
          };
        })).success;
      expected = false;
    };
    test-nway-intra-stratum-ok = {
      expr =
        (builtins.tryEval (buildN {
          strataOrder = [
            "structural"
            "resolution"
            "closure"
          ];
          equations = {
            a = eqAt "synthesized" [ "b" ] "closure";
            b = eqAt "synthesized" [ ] "closure";
          };
        })).success;
      expected = true;
    };
  };
}
