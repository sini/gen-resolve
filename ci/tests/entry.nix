# THE STANDALONE ENTRY, EXERCISED. The root `default.nix` is the non-flake path this repository
# documents — `ci/repl.nix` builds its surface with `import ../. { }`, and a consumer with no flake
# has nothing else. Every OTHER cell in this suite takes `genResolve` from `ci/flake.nix`, which
# imports `../lib` directly and so never evaluates the root shim: a shim that names a sibling's
# private formals can therefore be wrong in every release without one cell noticing. This is that
# cell.
#
# ★★ THE CELL IS PURE, AND THE PURITY IS A CONSEQUENCE OF HOW IT IS CALLED. The shim's four
# dependency defaults `builtins.fetchTree` the flake-locked revisions; supplying ALL FOUR explicitly
# means those defaults are never forced, so this reaches the network not at all. What it tests is
# the shim's SIGNATURE and its DELEGATION — which is precisely where the defect lives. The bare
# `import ../.. { }` form does NOT have this property, and the difference is measured rather than
# assumed: with the shim's `fetch` formal replaced by a `throw`, the bare form aborts on `gen-scope`
# and the supplied form evaluates clean.
#
# One cell, one key per sibling the shim CONSTRUCTS, because each key forces exactly that one:
#   scope — `reference`'s `compute` IS `scope.query { … }`, produced when the equation is built
#   graph — a schedule's circularity test is `graph.condensation` over the attr-dep edges
#   bind  — `terminalBind` is `bind.wrapAll`, which needs no resolution context to force
# `algebra` is deliberately not forced. It is reached only from inside a `cascade` compute, which
# needs a resolution context, and it is a dependency the shim takes as a bare value rather than
# constructing — there is no arity contract there to get wrong. It is nonetheless SUPPLIED below,
# like the other three: an unsupplied formal is a dormant `fetchTree` waiting for the first cell
# that reaches a `cascade`, and hermeticity that turns on which keys the expr happens to name is
# not a property of this file.
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
{
  genScope,
  genGraph,
  genAlgebra,
  genBind,
  lib,
  ...
}:
let
  # ★ ONE binding, read by BOTH cells. Duplicating the literal makes the control guard its own copy
  # and nothing else — measured: main copy broken ⇒ 2/2 exit 0 on a tree carrying a real member.
  needle = ''}/lib"[[:space:]]*\{'';

  # The same construction `ci/tests/purity.nix` uses, over the same file, for the same stated reason.
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # ★ ALL FOUR dependency formals, from the SAME bindings `ci/flake.nix` builds its `lib` output
  # from. That is what keeps this cell offline, and it is also what makes the cell a reading of the
  # SHIM: over two different substrate builds it would be exercising two libraries.
  entry = import ../.. {
    scope = genScope;
    graph = genGraph;
    algebra = genAlgebra;
    bind = genBind;
  };
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

  # ★ THE CELL ABOVE CANNOT SEE THIS CLASS, and the reason is the property that makes it hermetic:
  # it supplies every dependency formal explicitly, so the shim's `fetch`-backed DEFAULTS —
  # which is where the divergence lives — are never forced. Forcing them would put `builtins.fetchTree`
  # inside the suite. This cell reads the CONSTRUCTION instead of the outcome, which is strictly wider:
  # it also catches the member that never throws (a defaulted formal on the far side turns the loud arm
  # of the class silent) and the member that has not yet drifted.
  #
  # ★★ COMMENTS ARE STRIPPED FIRST, AND THAT IS LOAD-BEARING RATHER THAN TIDY. `ci/tests/purity.nix`
  # states the same property for the same reason and over this same file (`stripComments (builtins.readFile
  # ../../default.nix)`): the house convention for a FIXED member is a comment explaining why not `/lib`,
  # and a raw scan reds on that comment while the file is correct. MEASURED, in-suite, on a tree whose
  # member had just been fixed — with a comment PLANTED in the house idiom, because no live site reds
  # today: every existing such comment happens to write `` `./lib` `` (relative, uninterpolated), and
  # raw ≡ stripped across all 14 domain files at HEAD. The strip is PROPHYLACTIC, and that is the
  # point — it stops the next correctly-written comment from reddening a correct file.
  #
  # ★ `[[:space:]]*` spans the newline a formatter may put between `/lib"` and `{` — measured: a
  # line-anchored form misses exactly that.
  #
  # ★★ THE NEEDLE IS BOUND ONCE AND BOTH CELLS READ THAT BINDING. Two literals spelled the same are
  # TWO PREDICATES, and the control would then guard only its own copy: MEASURED — with the needle
  # duplicated, breaking the MAIN copy by one character gave `2/2 successful, exit 0` over a tree
  # carrying a real member, with the control still ✅ in the same run. That is §1.5's class — a second
  # signature nothing compares against the first — committed by the instrument built to detect it.
  # With the shared binding the same one-character break REDS THE CONTROL.
  #
  # ★ A bare `.../lib` with NO argument set is EXCLUDED, and the exclusion is a claim about the FAR SIDE
  # AT ITS PIN rather than about this file: it holds only while the target's `lib` is a value. All
  # nineteen such sites in this domain reach gen-prelude / gen-identity / gen-algebra, each measured
  # `"set"` 2026-08-29. It is NOT a property of the spelling — `den-hoag-jhsb` measured
  # `select ? import "${fetch "gen-select"}/lib"` in gen-pipe yielding a LAMBDA (gen-select's `lib` takes
  # `{ algebra }`), a silent member this predicate does not count — and this cell cannot observe its own
  # premise going false. See §4.4.
  flake.tests.entry.test-no-dependency-is-built-past-its-own-entry =
    let
      parts = builtins.split needle (stripComments (builtins.readFile ../../default.nix));
    in
    {
      # ★ THE ASSERTION IS ON THE COUNT. `reaches` is a diagnostic so a failure names the dependency,
      # but it is derived by a second match that a non-`fetch` spelling defeats — asserting on names
      # alone would read `[ ]` on a real member and pass.
      expr = {
        count = builtins.length (builtins.filter builtins.isList parts);
        reaches = map builtins.head (
          builtins.filter (m: m != null) (
            map (p: builtins.match ''.*fetch "(gen-[a-z-]+)"$'' p) (builtins.filter builtins.isString parts)
          )
        );
      };
      expected = {
        count = 0;
        reaches = [ ];
      };
    };

  # ★★ THE DETECTOR IS SHOWN ABLE TO FIRE, IN THE SAME RUN, ON THE SAME PREDICATE — `purity.nix`'s
  # standing rule and `den-hoag-e421`'s landed remedy. Without it, `count = 0` is equally consistent
  # with a needle that cannot match: MEASURED — one character changed in the needle reads
  # `{ count = 0; reaches = [ ]; }` on a file carrying three real members, i.e. byte-identical to this
  # cell's own `expected`. The planted member is REFLOWED, so it also pins the `[[:space:]]*` span.
  flake.tests.entry.test-control-the-entry-shape-check-discriminates = {
    expr = builtins.length (
      builtins.filter builtins.isList (
        builtins.split needle (stripComments ''
          {
            graph ? import "''${fetch "gen-graph"}/lib"
              { inherit prelude; },
          }: null
        '')
      )
    );
    expected = 1;
  };
}
