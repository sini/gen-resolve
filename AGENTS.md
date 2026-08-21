# gen-resolve — agent capability sheet

## Scope

The authoring vocabulary for semantic equations (`attr` / `nta` / `cascade` / `reference`) and the static attribute-dependency schedule built over their declared reads — the Knuth circularity test and the N-way stratum assert. Every computation is delegated to a sibling.

**The cold fold has LEFT.** Folding those equations into a sealed context is `gen-scope`'s `foldEquations`, which takes a schedule as an argument and reads its equations off it — the fold was always the evaluator's CALLER, and the two calls it made across that boundary are local ones there. `_scheduleWith` is the sole producer of the value it takes, which is why a caller of the fold still reaches for this library.

**The warm fold has LEFT.** `override` and `warmResolve` are `gen-memo`'s `warmOverride` and `warmResolve`, and the override cone that decided them went too. What the plane decides is REUSE, and it now decides it from the evaluator's own resolutional partition rather than from an attribute's declared stratum — so `_trackedAttrs` is gone from this surface and `trackedFor` is gone from the ecosystem. `stratumOf` survives in its **other** role, assigning the strata the schedule orders, and travels with `schedule.nix` wherever the ordering work lands.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim. `lib/default.nix` takes four sibling values (`scope`, `graph`, `algebra`, `bind`); `git grep -c <token> -- lib/` returns zero files for `gen-select`, `gen-schema`, `gen-aspects`, `gen-types`, `gen-merge`, `gen-flake`, `gen-dispatch`, `gen-pipe`, `nixpkgs`, `evalModules`, `mkOption` (positive control, same instrument, same run: `gen-resolve` 5 files, `scope.` 1, `graph.` 1, `algebra.` 1, `bind.` 1). The `memo` formal was retired; the plane is composed by callers holding both libraries rather than declared as a sibling here.

| Responsibility | Owner |
|---|---|
| The demand fixpoint itself — `lib.fix` memoization, `eval` / `evalWarm`, `circular` Kleene ascent, `query` / `queryReverse` / `collectionAttr` | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Graph topology — SCC condensation, `reachableFrom`, `dependentsOf` | `gen-graph` — "gen-graph: accessor-based graph query combinators" |
| Dirtiness / AFFECTED-set detection, and the WARM FOLD ITSELF (`build`, `affectedSet`, `warmOverride`, `warmResolve`) | `gen-memo` — the incremental plane, which the rebuilder core retired into. The warm fold and the override cone live there too, and the memo context the cold fold used to build is now composed by a caller holding both libraries: `ci/tests/resolve.nix` is that caller and the ecosystem's only site that FORCES `build` |
| Record-layer folding (`record.foldLayersTraced`) that `cascade` calls | `gen-algebra` — "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either" |
| Injecting external args into modules (`wrapAll`) | `gen-bind` — "gen-bind: module binding with external arguments for Nix" |
| Choosing a winner among matched rules — the dispatch STEP | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)". README §"The convergence loop" shows the LOOP composing with `dispatch` by threading domain state; gen-resolve holds no rule algebra |
| Matching graph positions by predicate | `gen-select` — "gen-select: selector algebra for attributed graph positions" |
| Identity, kinds, registries | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system" |
| Aspect traits / classification | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)" |
| Type checking / `verify` | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem" |
| Running `evalModules` over the materialized module list | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system". gen-resolve stops at the module LIST; the `evalModules` call lives only in `ci/tests/materialize.nix` as the equivalence oracle |
| The nixpkgs boundary — building systems from resolved values | `gen-flake` — "gen-flake — the pure composition boundary of the pure-gen module ecosystem" |
| General utilities | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem". Transitive only: each sibling carries its own, the `.lib` surface takes no direct prelude (`flake.nix` comment, `lib/default.nix` header) |
| Domain knowledge — what an attribute MEANS, NixOS, aspects, den's attribute names | the consumer. gen-resolve supplies accessor *functions* and never concrete node maps (README §Overview) |

## Exports

Entry: `inputs.gen-resolve.lib` (flake) or `import ./lib { scope; graph; algebra; bind; }`. The root `default.nix` is a shim that derives those deps from the pinned `flake.lock` via `fetchTree` and calls `import ./lib`. Flat namespace — no nested groups.

**Equation constructors** — `lib/equation.nix`. Each yields `Equation = { name; kind; compute; readsAttrs; stratum }` (5 keys, measured).

| Export | Signature |
|---|---|
| `attr` | `{ name; kind; compute; readsAttrs; stratum ? null } -> Equation` — `compute :: self -> id -> value` |
| `nta` | `{ name; spawn } -> Equation` — fixes `kind = "nta"`, `readsAttrs = [ ]`, `stratum = "structural"` |
| `cascade` | `{ name; channel; strata ? { }; combine ? "replace"; acc ? false } -> Equation` — fixes `kind = "cascade"`, `readsAttrs = [ "imports" ]`, `stratum = "resolution"` |
| `reference` | `{ name; select; target ? "includes" } -> Equation` — fixes `kind = "reference"`, `readsAttrs = [ "imports" ]`, `stratum = "resolution"` |

**Cold fold — NOT HERE ANY MORE.** It is `gen-scope`'s `foldEquations`, whose argument set is `{ roots; parseParent; schedule; declaredEdges ? (_: [ ]); settings ? { } }`. There is no `equations` formal — they are read off the schedule, so a caller cannot pair a schedule with equations it was not built from — and no `strataOrder` formal, because the order is `_scheduleWith`'s and is sealed nowhere. Build the schedule here, hand it there.

**Read-only consumers** — `lib/contract.nix`

| Export | Signature |
|---|---|
| `project` | `ctx -> id -> attr -> value` (`= ctx.eval.get id attr`) |
| `edges` | `ctx -> id -> [id]` (`= ctx.trace.<id>.deps`) |
| `why` | `ctx -> { id; attr } -> [ { id; attr } ]` — the cross-product `declaredEdges id` × `equations.<attr>.readsAttrs` |

**Terminal** — `lib/materialize.nix`

| Export | Signature |
|---|---|
| `terminalBind` | `{ modules; bindings; ... } -> [Module]` (`= (bind.wrapAll args).all`, i.e. wrapped modules ++ collision validators) |
| `materialize` | `ctx -> id -> value` — forces the hardcoded attribute name `"output-modules"` |
| `materializeAll` | `ctx -> type -> { <id> = value; }` — the argument is a node **type** (`ctx.eval.nodesOfType`) |

**Intra-eval incremental — NOT HERE ANY MORE.** `override` and `warmResolve` are `gen-memo`'s
`warmOverride` and `warmResolve`, and the override cone went with them. Both take the `ResolveCtx`
this library seals plus the evaluator, which the plane does not depend on and is handed:
`genMemo.warmOverride { inherit (genScope) evalWarm; } ctx { id; newDecls; }`. Warm-servability is no
longer decided from a declared stratum — it is the evaluator's own resolutional vocabulary.

**Fleet key** — `lib/classkey.nix`

| Export | Signature |
|---|---|
| `classKey` | `ctx -> id -> sha256-string` — digests the hardcoded attribute name `"resolved-aspects"` |

**Schedule builders**, `_`-prefixed but on the public `.lib` — `lib/schedule.nix`

| Export | Signature |
|---|---|
| `_scheduleWith` | `{ equations; strataOrder ? [ "structural" "resolution" ] } -> Schedule` |
| `_buildSchedule` | `equations -> Schedule` (`= _scheduleWith` at the default order) |

`_trackedAttrs` is **gone**. It computed the warm-served set from the declared stratum, one of the
two filters the derived classifier superseded; the other was `trackedFor` inside the warm fold.

**Returned shapes.** `Schedule` is this library's and carries 4 fields: `attrGraph`, `condensation`, `edges`, `equations`. **The sealed context is `gen-scope`'s** and carries 10, pinned there as an exact set by `fold-equations.test-ctx-sealed`: `accessor`, `attributes`, `declaredEdges`, `equations`, `eval`, `parseParent`, `roots`, `schedule`, `settings`, `trace`. Two fields that were on it here are gone — `builtCtx`, because building a memo context inside the evaluator would install the incremental plane inside the thing the plane is defined against, and `strataOrder`, which had no reader anywhere and whose only toucher was the cell asserting the seal. `trace.<id>` is `{ deps; hash }` with `hash` fixed at `null`. **The exact-set FORM is the part worth carrying, and the reason is worth carrying with it**: that cell was once a presence check, which passes for any context containing its named fields and says nothing about the rest, so it stayed green across ten, eleven and twelve fields while three prose sites went false behind it.

**Module-level but NOT on `.lib`** (absent from the drift output): `stratumOf` (`lib/equation.nix`), `defaultStrataOrder` and the un-prefixed `scheduleWith` / `buildSchedule` (`lib/schedule.nix`). `mkBuiltCtx` retired with the cold fold — the four lines it was are now written out at the one cell that forces the plane.

## Entry points by task

| Task | Reach for |
|---|---|
| Author a plain semantic equation | `attr { name; kind; compute; readsAttrs; }` |
| Grow the node grammar mid-fold (spawn children) | `nta { name; spawn; }` |
| Merge layered per-node config along import edges | `cascade { name; channel; combine?; acc?; }` |
| Resolve a value across an import edge (nearest binding) | `reference { name; select; }` |
| Gather from the nodes that import me | `reference { name; select; target = "neededBy"; }` |
| Fold everything into a context | `genScope.foldEquations { roots; parseParent; declaredEdges; schedule = _scheduleWith { equations = eqs; }; }` |
| Use more than two strata | pass `strataOrder` to `_scheduleWith` (index 0 = the base graph-shaping stratum) |
| Read a resolved value | `project ctx id attr` |
| Ask which nodes an id declared reads on | `edges ctx id` |
| Ask coarse name-level provenance | `why ctx { id; attr; }` |
| Force the terminal for one node / all nodes of a type | `materialize ctx id` / `materializeAll ctx type` |
| Inject external args into the emitted modules | `terminalBind { modules; bindings; }` inside the `output-modules` equation |
| Re-fold after one data edit | `genMemo.warmOverride { inherit (genScope) evalWarm; } ctx { id; newDecls; }` — another library |
| Re-fold after several data edits in one pass | `genMemo.warmResolve { inherit (genScope) evalWarm; } ctx { edits; }` — another library |
| Narrow cross-invocation reuse candidates | `classKey ctx id` (must be backed by a byte-identity gate — `lib/classkey.nix` header) |
| Exercise the schedule gates in isolation | `_scheduleWith` / `_buildSchedule` |

## Measured traps

Every row was evaluated in this run at rev `0ef3617` (a historical note, not a pin) against `R = import <repo>/lib { … }`, with the five siblings constructed from the repo's own `flake.lock` exactly as `default.nix` did at that rev. Shared fixtures: `roots2 = scope.buildNodes { parentGraph = scope.edge "child" "parent"; decls = { parent.v = 10; child.v = 1; }; types = { parent = "host"; child = "host"; }; }`; `xroots v = scope.buildNodes { importGraph = scope.edge "consumer" "producer"; decls.producer.v = v; }`; `croots = scope.buildNodes { importGraph = scope.edge "leaf" "base"; }` with a `ch` channel on each node; `te e = (builtins.tryEval e).success`. `tryEval` in this Nix catches only thrown/assert errors, so two rows below are recorded as the observed process failure instead.

### What the schedule analyses, and what the evaluator does

The two are declared on different surfaces and neither is derived from `compute`.

| Question | Answer, with evidence |
|---|---|
| What does the analysis read? | Exactly the `readsAttrs` list on each equation, further filtered to names that are themselves keys of `equations` — `lib/schedule.nix` `scheduleWith`, binding `edges`. `compute` is never inspected; `lib/equation.nix` states it directly: "compute is opaque -> nothing to infer" |
| At what granularity? | Attribute NAMES only, node-agnostic: `scheduleWith` builds its accessor from `builtins.attrNames equations`, with no node dimension |
| What does the evaluator read? | Whatever `compute` calls `self.get id attr` on, for any `id` and any `attr` that is a key of `equations` — `gen-scope`'s `eval` binding `get` dispatches on `attributes ? ${attrName}` and consults no `readsAttrs`. `git grep -c readsAttrs -- lib/` in `gen-scope` (rev `020d6e9`) matches zero files; positive control, same instrument, same run: `attributes` matches 4 files there |
| Is the dynamic read-set recoverable? | `gen-scope`'s `lib/eval.nix` states it is only recoverable via `evalDebug`'s fresh-self-per-get, which defeats the memo, so the graph's edge set is the inspectable contract. That library declares no read set at all — the body is the read set, and `ctx.trace.<id>.deps` derives from `ctx.accessor.edges` |
| Which lib files carry `readsAttrs`? | 3 of 8: `lib/equation.nix`, `lib/schedule.nix`, `lib/contract.nix` (`git grep -l readsAttrs -- lib/`) |

| Trap | Evidence |
|---|---|
| A `compute` that reads an attribute it did not declare passes the schedule and evaluates fine — the dep edge is simply absent | equations `{ self-v; sneaky }` with `sneaky.readsAttrs = [ ]` but `compute = self: id: self.get id "self-v" + 100`: the fold ⇒ succeeded, `ctx.schedule.edges "sneaky"` ⇒ `[ ]`, `eval.get "child" "sneaky"` ⇒ `101`. Positive control, same compute with `readsAttrs = [ "self-v" ]`: edges ⇒ `[ "self-v" ]`, value ⇒ `101`. ★ Re-measured through `_scheduleWith` + `gen-scope.foldEquations` after the fold moved; every reading is unchanged, which is the point — the analysis is this library's and the fold merely calls it |
| An undeclared mutual read is invisible to the Knuth circularity test; it terminates the evaluator with an **uncatchable** stack overflow | `a`/`b` whose computes read each other, both `readsAttrs = [ ]`: the fold ⇒ succeeded, `schedule.condensation.sccs` has no SCC of size > 1, and `nix eval` of `(tryEval (ctx.eval.get "child" "a")).success` exits 1 with `error: stack overflow; max-call-depth exceeded` — `tryEval` does not intercept it. Positive control, same computes with the reads declared: `_buildSchedule` ⇒ threw. Test: `test-noncircular-scc-throws` (`ci/tests/schedule.nix`) |
| The stratum partition assert is likewise over `readsAttrs` only — an undeclared `structural` → `resolution` read passes both the schedule and eval | `st` at `structural` whose compute does `self.get id "res"` on a `resolution` attr, `readsAttrs = [ ]`: `resolve` ⇒ succeeded, value ⇒ `8`. Positive control, identical compute with `readsAttrs = [ "res" ]`: `resolve` ⇒ threw. Tests: `test-stratum-violation-throws`, `test-nway-multihop-cone-throws` (`ci/tests/schedule.nix`) |
| A `readsAttrs` entry naming something that is not an equation is silently dropped from the graph; the eval-time read throws | `g.readsAttrs = [ "does-not-exist" ]`: the fold ⇒ succeeded, `schedule.edges "g"` ⇒ `[ ]`, `tryEval (eval.get "child" "g")` ⇒ `false`. Positive control, same context: `eval.get "child" "self-v"` ⇒ `1` |
| Because the analysis is node-agnostic, a name-level cycle whose per-node instantiation terminates is **rejected** | `a` reads `b` only on `child`, `b` reads `a` only on `parent`, both declared: the fold ⇒ threw. Same computes with `readsAttrs = [ ]`: the fold ⇒ succeeded, `eval.get "child" "a"` ⇒ `2`, `eval.get "child" "b"` ⇒ `2` |
| Cross-node reads have a **second, separate** declaration surface — `declaredEdges` — which the schedule never consults; under-declaring it serves a stale prior on a warm re-fold | `consumer.sees` reads `producer.p-val`. With `declaredEdges = id: if id == "consumer" then [ "producer" ] else [ ]`, bumping `producer.v` 1→9 ⇒ `109`; with `declaredEdges = _: [ ]` (which is also the **default**) ⇒ `101`, the stale value. The edited node always re-derives: `p-val` ⇒ `9` either way. **The surface is this library's and the consequence is measured in `gen-memo`**, at `warm-override-cross-node.test-undeclared-serves-stale`, which is where the fold that reads the cone now lives — this row states the trap and names its instrument rather than restating a figure about another repository's file |

### Stratum labels vs the stratum check

| Trap | Evidence |
|---|---|
| The label is assigned by kind at construction and is **never validated there**; only the schedule checks it | `stratumOf` (`lib/equation.nix`): `synthesized` ⇒ `"structural"`, `inherited` ⇒ `"structural"`, `circular` ⇒ `"resolution"`, an unknown kind `"totally-made-up"` ⇒ `"structural"` (the fall-through). `attr { stratum = "nonsense"; }` constructs and carries `stratum = "nonsense"`; `_buildSchedule` on it ⇒ threw (the unknown-stratum guard). Tests: `test-attr-circular-stratum`, `test-nway-unknown-stratum-throws` |
| An explicit `stratum` overrides the kind default for **any** kind, including `circular` | `attr { kind = "circular"; stratum = "structural"; }` ⇒ `stratum = "structural"`. Test: `test-attr-circular-explicit-structural` (`ci/tests/equation.nix`), `test-circular-structural-den-shape` (`ci/tests/schedule.nix`) |
| A plain `synthesized` attr defaults to the **base** stratum, so it may read nothing later | `stratumOf` fall-through ⇒ `"structural"`. **The second half of this row is struck**: it used to read "and is never warm-served", which was true of a classifier that no longer decides that question. Warm-servability is the evaluator's resolutional partition now, and a `synthesized` attribute is reusable unless its NAME is in the reserved structural namespace |
| `terminal` is exempt from the ordering check | `test-terminal-reads-resolution-ok`, `test-nway-terminal-exempt` (`ci/tests/schedule.nix`). Its former second half — "but **is** in the warm-served set" — is struck for the same reason as the row above |
| A hand-built equation with no `readsAttrs` key at all is accepted by the schedule as reading nothing (`or [ ]` in `scheduleWith`) | `_buildSchedule { a = { kind; stratum; compute; name; }; }` ⇒ succeeded. Positive control: `R.attr` without `readsAttrs` fails with `error: function 'attr' called without required argument 'readsAttrs'` — an arity error `tryEval` does not catch |
| The fold forces the schedule with `seq`, so gate failures throw where the caller made the call and not lazily on first read | The trap is real and **the code it describes is now `gen-scope`'s**, so this row points rather than restates: measure it at that repository's `fold-equations.test-a-throwing-schedule-is-refused-at-the-entry`, whose control beside it is a schedule that does not throw. What stays here is the gate itself — `schedule.test-stratum-violation-throws` and the six `test-nway-*` cells (`ci/tests/schedule.nix`) |

### Constructors, terminal, incremental, key

| Trap | Evidence |
|---|---|
| `cascade` applies `combine` **uniformly to every field** of the merged record, so a heterogeneous channel breaks non-`replace` strategies with an uncatchable type error | channel `{ k = [ … ]; only-base = 1; }` under `combine = "append"`: `nix eval` of `(tryEval (project ctx "leaf" "merged").only-base).success` exits 1 with `error: expected a list but found an integer: 1`. Homogeneous controls in the same run: all-list + `"append"` ⇒ `{ k = [ "base" "leaf" ]; }`, all-attrset + `"recursive"` ⇒ `{ k = { x = "base"; y = "leaf"; }; }`, heterogeneous + `"replace"` ⇒ `{ k = [ "leaf" ]; only-base = 1; }` |
| `combine = "semilattice-set"` is rejected unless `acc = true`; an unrecognised `combine` is rejected outright | `tryEval` at construction: no-acc ⇒ `false`, `acc = true` ⇒ `true`, `combine = "bogus"` ⇒ `false`, default ⇒ `true`. With `acc = true` on an all-list channel the fold runs ⇒ `{ k = [ "base" "leaf" ]; }`. Tests: `test-jsl-cascade-no-acc-throws`, `test-jsl-cascade-acc-ok` (`ci/tests/cascade.nix`) |
| `cascade`'s `strata` argument **shadows** the node's own `decls.<channel>` for that id | same channel, `strata = { }` ⇒ `{ k = "from-decls-leaf"; }`; `strata = { leaf.k = "from-strata-leaf"; }` ⇒ `{ k = "from-strata-leaf"; }` |
| `reference` rejects any `target` other than `"includes"` / `"neededBy"` at construction | `tryEval`: `target = "bogus"` ⇒ `false`, `"neededBy"` ⇒ `true`. Live directions on a `web1,web2 → db1` import graph: forward ⇒ `"database"`, reverse ⇒ `[ "w1" "w2" ]`, reverse on a node nobody imports ⇒ `[ ]`. Tests: `test-invalid-target-throws`, `test-includes-forward`, `test-neededBy-reverse` (`ci/tests/reference.nix`) |
| `why` reports only **cross-node** pairs — it never surfaces an intra-node read, and returns `[ ]` for an unknown attr rather than throwing | `child` declares an edge to `parent`; `why ctx { id = "child"; attr = "derived"; }` ⇒ `[ { id = "parent"; attr = "self-v"; } ]`, but `why ctx { id = "parent"; attr = "derived"; }` ⇒ `[ ]` even though `parent.derived` does read `parent.self-v`. `why ctx { id = "child"; attr = "no-such-attr"; }` ⇒ `[ ]`. `edges ctx "no-such-node"` ⇒ `[ ]`. Test: `test-why` (`ci/tests/contract.nix`) |
| The warm fold refuses edits to NTA-spawned nodes — only `roots` keys are editable (the refusal is `gen-memo`'s now; the NTA behaviour it refuses over is this library's) | `nta` spawning `spawned-1` under `host-a`: `eval.allNodes` ⇒ `[ "host-a" "spawned-1" ]`, `eval.get "spawned-1" "self-v"` ⇒ `42`, `ctx.roots ? spawned-1` ⇒ `false`, `tryEval (override ctx { id = "spawned-1"; … })` ⇒ `false`, same override on `host-a` ⇒ `true`. Test: `test-nta-grammar-growth` (`ci/tests/conformance.nix`) |
| Any edit whose `newDecls` merely *mentions* `includes` / `neededBy` / `__edges` / `parent` throws as a topology change; the old value is never compared | The trap is real and **the code it describes is now `gen-memo`'s** (`lib/warm.nix`), so this row points rather than restates: measure it at that repository's `warm-override.test-edge-move-throws` and `warm-resolve.test-batch-edge-move-throws`. A figure measured here about a file that left would decay silently |
| The plane's context is no longer a FIELD of the sealed context, so nothing forces it by accident and nothing hides an absent plane behind laziness either — a caller that wants it composes it and thereby forces it | `ci/tests/resolve.nix` is that composition and the ecosystem's only site forcing `build`; a **cyclic** `declaredEdges` still resolves on the cold path, measured at `gen-scope`'s `fold-equations.test-cyclic-declared-edges-leave-the-cold-path-alone` |
| `materialize` and `classKey` hardcode their attribute names and throw when the equation set lacks them | on a context with neither: `tryEval (materialize ctx "child")` ⇒ `false`, `tryEval (classKey ctx "child")` ⇒ `false`. `materializeAll ctx "nixos"` ⇒ `[ "h" ]` on a `nixos`-typed node, `materializeAll ctx "host"` ⇒ `[ ]` on the same context |
| `classKey`'s function-sentinel collapses closure-valued leaves, so two values differing only in a function digest identically | `resolved-aspects` = `{ fn = x: x; tag = "same"; }` vs `{ fn = x: x + 1; tag = "same"; }` ⇒ keys equal. Positive control, same fixture: `{ fn = x: x; tag = "different"; }` ⇒ key differs. `lib/classkey.nix` also documents that `sanitize` assumes a finite (non-self-referential) value — read, not exercised. Tests: `test-function-bearing-stable`, `test-function-bearing-distinct` (`ci/tests/classkey.nix`) |
| `terminalBind` returns more modules than it was given — `wrapAll … .all` appends the collision validators | one input module ⇒ 2 elements, and `materialize` of an `output-modules` equation built from it ⇒ 2. README §`terminalBind` records that an `error`-strategy collision is a lazy `config.warnings` contribution — read, not exercised. Test: `test-terminal-all-validator-safe` (`ci/tests/materialize.nix`) |
| `settings` is carried verbatim through the context and never consulted by any library | the fold with `settings = { anything = "carried"; }` ⇒ `ctx.settings` unchanged, re-measured through `gen-scope.foldEquations`. `git grep -c settings -- lib/` here now matches **nothing** (exit 1) — the parameter left with the fold; positive control, same instrument same run: `equations` matches 3 lib files |

## Theory

`README.md` §Theoretical Foundations is a table with an explicit **Implements** / **Informed by** column; the code comments restate the same anchors.

**Implements**

- **Knuth (1968), *Semantics of Context-Free Languages*** — the attribute-dependency graph (`a → b` iff `b ∈ readsAttrs a`) and the circularity test gating a cyclic SCC; `lib/schedule.nix` header and the throw text.
- **Vogt, Swierstra & Kuiper (1989), *Higher-Order Attribute Grammars*** — `nta` (§2 node-spawning attribute) and the well-definedness gate lifted onto Knuth's test. `lib/schedule.nix` header scopes it: the gate discharges the Knuth/reduced-AG acyclicity half **only**; §3.2 HOAG well-definedness (finite tree expansion) is left to runtime — a non-terminating `spawn` diverges at eval.
- **Neron, Tolmach, Visser & Wachsmuth (2015), *A Theory of Name Resolution*** — the D>I>P strata fold in `cascade` over neron-ordered import layers (`scope.collectionAttr { traverse = "neron"; }`), and the staged name-resolution-then-resolution anchor the schedule's own comment names as the honest source of the partition.
- **van Antwerpen et al. (2016), Statix §4.3** — the stratum partition assert, generalized N-way over a declared `strataOrder`, **with Apt–Blair–Walker (1988)** for the positive-dependency admission: a rule may read strata ≤ its own, a strictly-later read is the violation. Both cited in `lib/schedule.nix` and in the throw text.
- **Mokhov, Mitchell & Peyton Jones (2018), *Build Systems à la Carte*** §4.1 — Nix laziness *is* the runtime schedule; `lib/default.nix` states that gen-resolve never re-orders thunks, and the fold that calls the evaluator says the same at `gen-scope`.
- **Sloane, Kats & Visser (2010), *A Pure Object-Oriented Embedding of Attribute Grammars*** §2.2 — iterate-to-fixpoint over an all-`circular` SCC. `lib/schedule.nix` cites this as "Sloane 2009"; README as 2010.
- **Reps, Teitelbaum & Demers (1983)** §4.3 — the AFFECTED set. The claim and the code stating it moved to `gen-memo` with the override cone: the topological reverse cone is a sound over-approximation, never RTD's exact AFFECTED.
- **Hedin (2000), *Reference Attributed Grammars*** — forward `reference`, nearest binding across imports.

**Informed by** (README's own label; no result claimed): Hedin & Magnusson (2003) *JastAdd* inter-type declarations for the reverse `neededBy` gather; Reynolds (1972) §5 environment binding for `gen-bind.wrapAll` closure-based arg injection — `lib/materialize.nix` repeats the hedge that this is **not** defunctionalization, the arrow type is retained; Arntzenius & Krishnaswami (2016) *Datafun* for the monotone/least-fixpoint reading of the ascent; Radul & Sussman (2009) *The Art of the Propagator* for quiescence as the stability criterion; Acar (2002) §7 for the reverse-topological splice. `lib/materialize.nix` additionally names Lorenzen (2025) inspectable lazy constructor for `deferredModule` class content (Informed-by).

`lib/classkey.nix` claims no paper: its header states the key is a conservative narrowing device, **not** a soundness proof, and that any consumer reusing on it must back it with a drvPath byte-identity gate.

**Checked invariant**: the library is `nixpkgs.lib`-free. `ci/tests/purity.nix` `test-library-source-is-dependency-free` scans comment-stripped `lib/**.nix` plus the root `flake.nix` and `default.nix` for the tokens `nixpkgs`, `lib.`, `{ lib }`, `{ lib,`, `evalModules`, `mkOption`.

## Drift check

```sh
nix eval --json .#lib --apply 'l: builtins.attrNames l'
```

Current output (verbatim):

```json
["_buildSchedule","_scheduleWith","attr","cascade","classKey","edges","materialize","materializeAll","nta","project","reference","terminalBind","why"]
```

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml`):

```sh
nix flake check ./ci
```
