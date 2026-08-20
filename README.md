# gen-resolve — demand-driven RAG evaluator over scope graphs

[![CI](https://github.com/sini/gen-resolve/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-resolve/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Pure-Nix, `nixpkgs.lib`-free **semantic-equation vocabulary and static attribute-dependency schedule** for higher-order reference attribute grammars over algebraic scope graphs. You declare equations here and build a schedule over their declared reads; `gen-scope.foldEquations` folds them into a demand fixpoint; `materialize` forces the terminal and binds the result.

gen-resolve owns the static attribute-dependency *schedule* (Knuth 1968 dependency graph + the Vogt 1989 HOAG well-definedness gate + the N-way stratified partition assert, default two-stratum) and the equation vocabulary the schedule is built over. **The cold fold has left**: folding those equations into a sealed context is `gen-scope.foldEquations`, which takes a schedule as an argument and reads its equations off it, so a caller cannot pair a schedule with equations it was not built from. Every actual computation is a hard-boundary delegation to a pure sibling: gen-resolve supplies accessor *functions*, never concrete node maps, and domain knowledge (NixOS, aspects, den's attributes) stays in the consumer. Runtime evaluation order is demand — Nix laziness inside `gen-scope.eval`'s `lib.fix` (Mokhov 2018 §4.1); gen-resolve never re-orders thunks.

gen-resolve is **Class B**: it declares four pure gen siblings (`gen-scope`, `gen-graph`, `gen-algebra`, `gen-bind`), and `lib/` reads all four. `gen-prelude` is a transitive dependency only — each sibling carries its own; the `.lib` surface takes no direct prelude. The library (`lib/`) is `nixpkgs.lib`-free (enforced by `ci/tests/purity.nix`); nixpkgs is pulled only in `ci/` for the test harness and the evalModules-equivalence oracle.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Usage](#usage)
- [Delegation — one instrument per sibling](#delegation--one-instrument-per-sibling)
- [The static schedule (owned) vs runtime order (delegated)](#the-static-schedule-owned-vs-runtime-order-delegated)
- [The convergence loop (owned)](#the-convergence-loop-owned)
- [The warm fold has left](#the-warm-fold-has-left)
- [`terminalBind` and `evalModules`](#terminalbind-and-evalmodules)
- [The class KEY and its scope](#the-class-key-and-its-scope)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

gen-resolve authors a computation as a set of **semantic equations** over a scope graph and folds
them to a demand fixpoint. There are exactly four equation constructors — the *only* authoring
surface:

| constructor | kind | reads | what it is |
|---|---|---|---|
| `attr { name; kind; compute; readsAttrs; stratum? }` | as given | explicit | a plain semantic equation over the dependency DAG (Knuth 1968) |
| `nta { name; spawn }` | `nta` | `[]` | a non-terminal attribute — the grammar *grows* mid-fold as new typed nodes are spawned (Vogt 1989 §2) |
| `cascade { name; channel; strata?; combine?; acc? }` | `cascade` | `["imports"]` | a D>I>P strata fold over the neron-ordered import layers (Neron 2015 §2); `combine ∈ {replace, append, recursive}` unconditional, or `semilattice-set` (JSL/ACI) iff `acc = true` |
| `reference { name; select; target? }` | `reference` | `["imports"]` | a forward reference attribute (nearest binding, Hedin 2000) or a reverse `neededBy` gather (Hedin & Magnusson 2003) |

`gen-scope.foldEquations { roots; parseParent; schedule; declaredEdges?; settings? }` folds these
into a sealed context, the `schedule` being `_scheduleWith { equations = …; }` built here; read-only
consumers (`project`, `edges`, `why`) query that context; `materialize` forces the terminal
`output-modules` attribute and binds via `gen-bind`. Intra-eval incremental re-folding is **no longer
here** — see [The warm fold has left](#the-warm-fold-has-left).

The **accessor pattern** is the boundary: gen-resolve hands each sibling a record of functions
(`{ nodes; edges; parent; nodeData }`) describing structure, and asks questions about it. It never
stores the graph and never carries domain knowledge.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record, search monad, either, intensional identity) |
| [gen-types](https://github.com/sini/gen-types) | Clean-room MIT structural type checker (leaf/poly checkers; `verify: v → null\|err`) |
| [gen-merge](https://github.com/sini/gen-merge) | Byte-mode module merge engine (`evalModuleTree`, byte-identical to nixpkgs `lib.evalModules` over the priority subset) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs); re-hosted on gen-merge |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch); re-hosted on gen-merge |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Relational rule dispatch STEP (stratified groups, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-memo](https://github.com/sini/gen-memo) | The incremental plane — decides reuse, never evaluates (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | Pure-Nix vars/secrets (den-agnostic) |
| [gen-flake](https://github.com/sini/gen-flake) | The nixpkgs boundary — compose purely, inject resolved values, build NixOS systems (value-injection) |

## Usage

gen-resolve exposes a single `.lib` value output. Source lives in `lib/`; it is a function of the
four sibling `.lib` values (Class B).

### As a flake input

```nix
{
  inputs.gen-resolve.url = "github:sini/gen-resolve";
  outputs = { gen-resolve, ... }:
    let
      resolve = gen-resolve.lib;
    in {
      # resolve.attr / resolve.nta / resolve.cascade / resolve.reference
      # resolve.resolve / resolve.project / resolve.materialize / ...
    };
}
```

### Without flakes / programmatic

The `.lib` consumes the already-constructed sibling `.lib` values — pass them by name:

```nix
let
  resolve = import ./path/to/gen-resolve/lib {
    scope   = gen-scope.lib;
    graph   = gen-graph.lib;
    algebra = gen-algebra.lib;
    bind    = gen-bind.lib;
  };
in
gen-scope.lib.foldEquations {
  roots        = myScopeNodes;         # from gen-scope.buildNodes
  schedule     = resolve._scheduleWith { equations = { /* attr/nta/cascade/reference */ }; };
  parseParent  = id: myParent id;
  declaredEdges = id: myEdges id;      # consumer→producer, MUST over-declare
}
```

## Delegation — one instrument per sibling

Every computation is a hard-boundary delegation. gen-resolve owns only the schedule and the loop.

| concern | sibling | theory |
|---|---|---|
| demand fixpoint (runtime order = Nix laziness) | `gen-scope` `eval` / `evalWarm` | Mokhov 2018 §4.1 |
| attribute-dependency topology / condensation / reverse cone | `gen-graph` `condensation` / `reachableFrom` / `dependentsOf` / `coneRank` | Knuth 1968 |
| dirtiness oracle (deferred cross-invocation layer) | `gen-memo` `build` / `affectedSet` | Mokhov 2018 rebuilder / RTD 1983 |
| strata fold (Neron D>I>P; `cascade.combine` = the per-field strategy) | `gen-algebra` `record.foldLayersTraced` | Neron et al. 2015 §2 |
| terminal module binding (closure-based / partial-application arg injection) | `gen-bind` `wrapAll` | Reynolds 1972 §5 environments (informed by) |
| convergence loop (Kleene ascent over a `circular` SCC) | `gen-scope` `circular` | Sloane 2010 §2.2 |

## The static schedule (owned) vs runtime order (delegated)

The schedule is built once — `_scheduleWith` at the caller's `strataOrder` (default two-stratum) —
and the fold `seq`-forces it and carries it edit-invariant in the sealed context. It:

- builds the Knuth attribute-dependency graph (`a → b` iff `b ∈ readsAttrs a`);
- runs the **Vogt well-definedness gate**: a cyclic SCC is admissible iff every member is a
  declared `circular` attribute (Sloane 2010 §2.2 iterate-to-fixpoint); otherwise it throws the
  Knuth 1968 circularity error;
- runs the **stratum partition assert** (van Antwerpen 2016 §4.3, generalized N-way): an attribute's
  read-cone may not reach a *strictly-later* stratum in the declared order (the `terminal` sink is
  exempt), so every query observes a region complete up to its own stratum. The shipped two-stratum
  case (`structural` may not reach `resolution`) is the default order — see below.

Runtime order is never scheduled by gen-resolve — it is Nix demand inside the delegated fixpoint.

### Stratum order (N-way schedule)

`_scheduleWith` takes an optional `strataOrder` — the declared total order of strata, index 0 = the
base graph-shaping stratum. It is the schedule's own argument and is not carried on the sealed
context: no reader anywhere asked the context for it. The static schedule enforces the
**stratified partition** (Apt–Blair–Walker 1988; van Antwerpen 2016 §4.3): a rule may read attributes
at strata **≤ its own** (positive dependency); reading a **strictly-later** stratum is a schedule
error. `terminal` is the materialization sink — exempt (it may read any stratum). Default order:
`[ "structural" "resolution" ]`, under which the schedule reproduces the shipped two-stratum
discipline (a structural graph-builder may not depend on a resolution result).

- `_scheduleWith { equations; strataOrder ? [ "structural" "resolution" ] }` — the N-way entry, and
  the producer of the value `gen-scope.foldEquations` takes.
- `_buildSchedule` — the same builder at the default order.

Every non-`terminal` attribute's declared stratum must appear in `strataOrder` (the unknown-stratum
guard throws NAMED at schedule time).

## The convergence loop (owned)

gen-resolve owns the convergence **LOOP** — the least-fixpoint Kleene ascent that resolves a
mutually-recursive `circular` region. The loop is `gen-scope.circular`'s iterate-to-fixpoint over
the circular-attribute SCCs (Sloane 2010 §2.2), threaded as both the cold fold and the warm
re-fold. It is *not* a runtime scheduler (that stays Mokhov-2018-§4.1 demand, delegated to
`gen-scope`); it is the static/definitional ascent that converges an `all-circular` SCC.

The loop and the relational-dispatch STEP are cleanly separable. `gen-dispatch.dispatch` is a pure
step — a function of `(rules, context)` — so this loop composes with it by threading the plain
domain state: each pass is one `dispatch`, its output context is the next iterate, and the actions
are read off the fixpoint by one post-convergence dispatch:

```nix
step      = _self: _id: ctx: (genDispatch.dispatch (cfg // { context = ctx; })).context;
converged = (gen-scope.circular { init = ctx0; inherit eq; } step) { } null;
actions   = (genDispatch.dispatch (cfg // { context = converged; })).actions;
```

Recomputing at the fixpoint makes the action set a function of the converged state, never the
iteration path (a confluence guarantee), so no cross-pass accumulator is threaded through the
circular value — the domain state is the only thing the ascent carries. The monotone /
least-fixpoint reading of the ascent follows Arntzenius & Krishnaswami 2016 (Datafun); quiescence
(`eq` reaching a fixed point ⇒ halt) is the Radul & Sussman 2009 propagator stability criterion.

## The warm fold has left

`override` and `warmResolve` are **`gen-memo`'s `warmOverride` and `warmResolve`**, and the override
cone that decided them went with them. Deciding what may be reused from a prior evaluation is the
incremental plane's whole concern; this library resolves and schedules.

```nix
genMemo.warmOverride { inherit (genScope) evalWarm; } ctx { id = "web2"; newDecls = { class = "db"; }; }
```

The evaluator is passed at the call because the plane declares no evaluator dependency: it decides
for an evaluator it is handed. The fold seals `attributes` into the context for exactly this — what a
re-evaluation needs is the attribute functions, and the equation record (with its `stratum`,
`readsAttrs` and `kind`) stays here.

**What changed in the move, beyond the address.** Warm-servability used to be decided by an
attribute's **declared stratum** — `stratum != base`, computed twice, in `override.nix` and in
`resolve.nix`. It is now the evaluator's own **resolutional vocabulary**: its attribute names minus
the structural partition (`children`, `derived-children`, `edges-*`, `includes`). A derived
classifier governs over a declared one, and the derivation was available. Two consequences are worth
stating rather than discovering:

- **Reuse is wider.** Under the declared filter a plain `synthesized` attribute defaulted to the base
  stratum and was **never** warm-served. Measured on this repository's own former `ci/tests/override.nix`
  fixture, the tracked set was `[ ]` — that suite warm-served nothing at all. Under the derived
  classifier those same attributes are reusable.
- **Structure is recomputed more.** The partition now covers the whole `edges-*` family and
  `includes`, not two literal names, so a warm evaluation pays edge-set recomputation it did not pay
  before. That is a cost fact, not a correctness fact: an edge set *is* the labelled reachability
  relation, and the reason structure is always recomputed applies to it exactly.

`stratumOf` survives the supersession in its **other** role — assigning the strata `schedule.nix`
orders, with the ABW gate — and travels with the schedule wherever the ordering work lands.

> **Soundness (c) travelled too.** Warm-serving is sound only if `declaredEdges` **over-declares**
> every cross-node read (consumer→producer). Under-declare, and a consumer outside the declared cone
> is served its *stale* prior value — `gen-memo`'s `ci/tests/warm-override-cross-node.nix` witnesses
> both branches.

The plane's memo context is **no longer a field of the sealed context at all**. Building it inside the
evaluator would install the plane inside the thing the plane is defined against, so a caller that
wants one composes it — `gen-memo.build` over the context's own accessor, four lines, which is the
direction this seam already runs. `ci/tests/resolve.nix` is that composition and the ecosystem's only
site that forces `build`. A cyclic node graph still resolves on the cold path, for the same reason it
always did: nothing there walks the declared edges.

## `terminalBind` and `evalModules`

`terminalBind = (gen-bind.wrapAll args).all` — the wrapped config modules **plus** the collision
validators. The conformance oracle drives that full `.all` set through a real `lib.evalModules` and
asserts the resolved config is byte-identical to the equivalent flat module list. This relies on
gen-bind emitting an **evalModules-safe** validator (a lazy `config.warnings` contribution, not an
eager `builtins.seq` that would force `config._module.args` at module-collection time and recurse);
that fix landed in gen-bind alongside this library.

> **m4 — error-strategy collisions are LAZY.** Because the validator is a lazy `config.warnings`
> contribution, an `error`-strategy collision throws only when `config.warnings` is demanded. A
> NixOS path forces warnings (via `toplevel`), so it surfaces there; a non-NixOS assembly that never
> forces `warnings` will silently swallow the collision — such a consumer must force
> `config.warnings` / `assertions` or use a strict gate.

## The class KEY and its scope

`classKey ctx id = sha256(toJSON (sanitize (project ctx id "resolved-aspects")))`, arg-shape
included. Function-bearing leaves sanitize to a stable sentinel (no throw, no false collision across
distinct non-function parts).

It is a **conservative narrowing key, NOT a soundness proof.** It narrows reuse candidates; it does
not prove interchangeability. Reuse keyed on it is sound *only* when the designated attribute is the
COMPLETE determinant of the reused output — the region must be def-disjoint from every per-scope
delta AND fixpoint-closed. Any consumer MUST back it with a **byte-identity gate** (drvPath
equality) as the total oracle. Key narrows; gate decides. The cache and gate are a deferred
cross-invocation layer; v1 ships the key only.

Three sharing layers — know which one this is:

- **(a) intra-eval attribute memo** — `gen-scope`'s `lib.fix` `_eval`; free, already happening.
- **(b) cross-invocation resolved-value reuse** — keyed on `classKey`; the cache and byte-identity
  gate are DEFERRED. v1 ships the key only.
- **(c) `evalModules` config-snapshot sharing** — gen-resolve sits **upstream of `evalModules`**: it
  produces per-node module *lists* (`terminalBind`) and shares at the *resolution* layer, not the
  config-snapshot layer.

> **m5 — the function-sentinel erases closure arg-shape.** `sanitize` maps every function to ONE
> sentinel, so two nodes whose resolved value differs only in a closure-valued argument digest to
> the SAME key. This is safe *only* under the byte-identity gate above; for the key itself to
> discriminate, a consumer must **defunctionalize parametric args to data** (a Reynolds obligation)
> before they reach the keyed attribute. `sanitize` also assumes a finite (non-self-referential)
> value.

## API Reference

### Equation constructors

The ONLY authoring surface. Each yields
`Equation = { name; kind; compute :: self → id → value; readsAttrs; stratum }`.

```
attr      : { name; kind; compute; readsAttrs; stratum? } → Equation
nta       : { name; spawn }                               → Equation
cascade   : { name; channel; strata?; combine?; acc? }    → Equation
reference : { name; select; target? }                     → Equation
```

**`attr`** — a plain semantic equation. `compute self id` reads other attributes via `self.get id attr` and node data via `(self.node id).decls`. `readsAttrs` declares the intra-node reads that
build the Knuth dependency edge. `stratum` may be given explicitly (honored first, for any kind);
otherwise it is kind-derived.

```nix
resolve.attr {
  name = "plus-one"; kind = "synthesized"; readsAttrs = [ "self-v" ];
  compute = self: id: self.get id "self-v" + 1;
}
```

**`nta`** — a non-terminal attribute. `spawn self id` returns a map of *new* typed nodes; the
grammar grows mid-fold and each spawned node is a real node carrying its own attributes. Stratum
`structural`, reads `[]`.

```nix
resolve.nta {
  name  = "children";
  spawn = self: id: lib.filterAttrs (_: n: n.parent == id) roots;
}
```

**`cascade`** — a D>I>P strata fold over the neron-ordered import layers.
`combine ∈ { "replace" (default, last-wins), "append" (list concat), "recursive" (deep //) }` are the
associative merges, admitted **unconditionally**. `"semilattice-set"` (the JSL/ACI set-union
combine — associative, commutative, idempotent) is admitted **only** when the production also
declares `acc = true`. The ascending-chain condition (ACC / finite carrier height) is what bounds
the semi-naïve fixpoint, and it is undecidable from an arbitrary `combine`; so it is a *declared*
carrier property, not one gen-resolve infers — `cascade { combine = "semilattice-set"; }` without
`acc = true` throws at registration. Delegates to `gen-algebra.record.foldLayersTraced`
(least-specific-first, LAST wins). Stratum `resolution`.

**`reference`** — a forward or reverse reference attribute. `target = "includes"` (default) resolves
the nearest binding across imports (Hedin 2000); `target = "neededBy"` reverse-gathers over the
nodes that import this one (Hedin & Magnusson 2003), delegated to `gen-scope.queryReverse`. Stratum
`resolution`.

### The cold fold and its sealed context — `gen-scope`'s

```
gen-scope.foldEquations : { roots; parseParent; schedule; declaredEdges?; settings? } → ResolveCtx
```

Returns a sealed **10-field** `ResolveCtx = { accessor; attributes; declaredEdges; equations; eval; parseParent; roots; schedule; settings; trace }`. There is no `equations` formal — they are read off the schedule, so the seal cannot carry a schedule nobody folded — and no `strataOrder` field, which had no reader in any repository measured.

> **The count is measured, and the phrasing it replaces was wrong for longer than one field.** This
> line claimed a sealed context of ten and enumerated ten. `strataOrder` was missing from it when
> that field was added, `attributes` when the warm fold left, and the sealed test could not say so
> because it asserted PRESENCE of ten names rather than the exact set — so it passed unchanged at
> ten, eleven and twelve. `test-ctx-sealed` now compares `builtins.attrNames ctx` against the exact
> list, which is the arming `gen-memo`'s `test-lib-exports-the-plane` already had.

Folds `equations.compute` into `gen-scope.eval`; `seq`-forces the schedule the caller handed it, so a
gate failure throws at the call and not lazily on a first read.
`accessor.edges = declaredEdges` is the consumer→producer edge and MUST over-declare (soundness
condition (c)). `trace.<id>.deps` is the eager recorded read-edge set.

### Consumer contract (read-only)

```
project : ResolveCtx → id → attr → value    # = ctx.eval.get id attr (no class-content forcing)
edges   : ResolveCtx → id → [Dep]           # = ctx.trace.<id>.deps (declared read-edges)
why     : ResolveCtx → { id; attr } → [Dep] # NAME-only static provenance (over-approximation)
```

`why` returns the cross-product of declared node-edges × the attr's `readsAttrs` as `[Dep]`
(`Dep = { id; attr }`). It is coarse — an over-approximation, not per-`(id, attr)` precise.

### Terminal

```
terminalBind   : args → [Module]          # = (gen-bind.wrapAll args).all
materialize    : ResolveCtx → id → config # forces "output-modules" (the only gen-bind site)
materializeAll : ResolveCtx → class → { id → config }
```

### Intra-eval incremental — not on this surface

```
gen-memo.warmOverride : { evalWarm } → ResolveCtx → { id; newDecls } → ResolveCtx
gen-memo.warmResolve  : { evalWarm } → ResolveCtx → { edits }        → ResolveCtx
```

Both take the `ResolveCtx` this library seals and hand it back re-evaluated. Edge-moves throw;
non-root edits throw. See [The warm fold has left](#the-warm-fold-has-left).

### Fleet KEY

```
classKey : ResolveCtx → id → sha256-string  # conservative reuse-narrowing digest
```

### Schedule

The N-way knob is `_scheduleWith`'s `strataOrder` argument. The schedule builders are exposed on the
`.lib` `_`-prefixed:

```
_scheduleWith : { equations; strataOrder ? [ "structural" "resolution" ] } → Schedule
_buildSchedule : equations → Schedule   # = _scheduleWith at the default order (back-compat)
```

In `lib/schedule.nix` these are `scheduleWith` / `buildSchedule`; the `.lib` re-exports them
`_`-prefixed. `_scheduleWith` is the N-way schedule builder (Knuth graph + Vogt gate + the stratified
partition assert over `strataOrder`); `_buildSchedule` is it at the default two-stratum order. The
fold `seq`-forces whichever of them built its argument, so the well-definedness gate and the stratum
partition run at the call; the `schedule` suite exercises the gate in isolation.

## Testing

Tests use [nix-unit](https://github.com/nix-community/nix-unit); the CI flake (`ci/`) pins nixpkgs
for the harness and the evalModules-equivalence oracle. The library itself is `nixpkgs.lib`-free
(enforced by `ci/tests/purity.nix`).

```bash
nix flake check ./ci                       # all suites + purity + the evalModules oracle
nix build ./ci#formatter.x86_64-linux      # then run ./result/bin/* . to format
```

Pre-publish, append `--override-input gen-resolve <path-to-this-repo>` so the CI resolves the local
tree. There are **53 tests across 10 suites** (`equation`, `schedule`, `resolve`, `materialize`,
`cascade`, `classkey`, `contract`, `reference`, `conformance`, `purity`) — the `conformance` suite is
the central oracle (demand-order == from-scratch toposort, the two schedule gates throw, NTA
grammar-growth), and the `resolve` suite is now the plane composition and the one site that forces
`gen-memo.build`. The `override`, `override-cross-node` and `warm-resolve` suites moved to `gen-memo`
with the fold they are about, and `conformance`'s override property moved with them.

## Theoretical Foundations

| Paper | Relationship | Used for |
|-------|-------------|----------|
| Knuth (1968) "Semantics of Context-Free Languages" | **Implements** | The attribute-dependency schedule (`a → b` iff `b ∈ readsAttrs a`) and the circularity test that gates a cyclic SCC |
| Vogt, Swierstra & Kuiper (1989) "Higher-Order Attribute Grammars" | **Implements** | Non-terminal attributes (`nta`) — the grammar grows mid-fold — and the HOAG well-definedness gate lifted onto Knuth's circularity test |
| Neron, Tolmach, Visser & Wachsmuth (2015) "A Theory of Name Resolution" | Implements | The D>I>P strata fold (`cascade`) over neron-ordered import layers; parent-chain / reference resolution over scope graphs |
| van Antwerpen et al. (2016) "A Constraint Language for Static Semantic Analysis" (Statix) | Implements | The stratified partition assert (§4.3), generalized N-way over a declared `strataOrder`; default two-stratum: a `structural` cone may not reach a `resolution` attribute (with Apt–Blair–Walker 1988 for the positive-dependency admission) |
| Mokhov, Mitchell & Peyton Jones (2018) "Build Systems à la Carte" | **Implements** | Demand-driven runtime order (§4.1) — Nix laziness *is* the schedule; the rebuilder dimension backs the deferred cross-invocation oracle |
| Sloane, Kats & Visser (2010) "A Pure Object-Oriented Embedding of Attribute Grammars" | Implements | The convergence loop — iterate-to-fixpoint (Kleene ascent, §2.2) over an `all-circular` SCC |
| Reps, Teitelbaum & Demers (1983) "Incremental Context-Dependent Analysis" | Implements | The AFFECTED set; the topological reverse cone is a sound over-approximation of it |
| Hedin (2000) "Reference Attributed Grammars" | Implements | Forward reference attributes (`reference`, nearest binding across imports) |
| Hedin & Magnusson (2003) "JastAdd" | Informed by | Inter-type declarations — the reverse `neededBy` gather |
| Reynolds (1972) "Definitional Interpreters for Higher-Order Programming Languages" | Informed by | Closure-based (partial-application) external-arg injection via `gen-bind.wrapAll` — Reynolds' environment binding (§5 `ENV`/`ext`); **not** defunctionalization per se (the arrow type is retained). Mirrors gen-bind's own hedge. |
| Arntzenius & Krishnaswami (2016) "Datafun: A Functional Datalog" | Informed by | The monotone / least-fixpoint reading of the convergence ascent |
| Radul & Sussman (2009) "The Art of the Propagator" | Informed by | Quiescence as the loop's stability criterion |
| Acar (2002) "Self-Adjusting Computation" | Informed by | Reverse-topological splice of a change through the dependency cone |

## License

MIT — see `LICENSE`.
