# Task 9 — the fleet KEY (D8). classKey digests a node's resolved `resolved-aspects` value INCLUDING
# arg-shape; equal resolved values collapse to one key, differing arg-shape splits, and function-bearing
# values digest to a stable sentinel (no throw, no false collision across distinct non-function parts).
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve) resolve classKey;
  roots = genScope.buildNodes {
    decls = {
      a = {
        aspects = {
          x = 1;
        };
      };
      b = {
        aspects = {
          x = 1;
        };
      }; # equal to a
      c = {
        aspects = {
          x = 2;
        };
      }; # differs in arg-shape
      d = {
        aspects = {
          x = 1;
          f = (y: y);
        };
      }; # function-bearing
      e = {
        aspects = {
          x = 2;
          f = (y: y);
        };
      }; # function-bearing, differs in x
    };
    types = {
      a = "host";
      b = "host";
      c = "host";
      d = "host";
      e = "host";
    };
  };
  eqs = {
    resolved-aspects = genResolve.attr {
      name = "resolved-aspects";
      kind = "synthesized";
      stratum = "resolution";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.aspects or { };
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
    parseParent = _: null;
  };
in
{
  flake.tests.classkey = {
    # identical resolved value -> identical key (the fleet class-collapse)
    test-equal-values-equal-key = {
      expr = classKey ctx "a" == classKey ctx "b";
      expected = true;
    };
    # differing arg-shape -> differing key
    test-differing-values-differ = {
      expr = classKey ctx "a" == classKey ctx "c";
      expected = false;
    };
    # function-bearing value digests to a stable sentinel (never throws)
    test-function-bearing-stable = {
      expr = (builtins.tryEval (classKey ctx "d")).success;
      expected = true;
    };
    # function-bearing values differing in a non-function part still get distinct keys (no false collision)
    test-function-bearing-distinct = {
      expr = classKey ctx "d" == classKey ctx "e";
      expected = false;
    };
  };
}
