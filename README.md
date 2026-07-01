# gen-resolve

Pure-Nix, `nixpkgs.lib`-free, **demand-driven higher-order reference-attribute-grammar
evaluator** — `resolve` / `materialize` over algebraic scope graphs.

gen-resolve is the **conductor**. It owns exactly two things: the static
attribute-dependency *schedule* (Knuth 1968 dependency graph + the Vogt 1989 HOAG
well-definedness gate + the two-stratum partition assert) and the cold/warm *fold* into the
demand fixpoint. Every actual computation is a hard-boundary delegation to a pure sibling. It
supplies accessor *functions*, never concrete node maps; domain knowledge (NixOS, aspects,
den's attributes) stays in the consumer. Runtime evaluation order is demand — Nix laziness
inside `gen-scope.eval`'s `lib.fix` (Mokhov 2018 §4.1); gen-resolve never re-orders thunks.

## Surface

| op | what it does |
|---|---|
| `attr` / `nta` / `cascade` / `reference` | the four equation constructors — the ONLY authoring surface |
| `resolve { roots; equations; parseParent; declaredEdges?; settings? }` | cold fold → sealed `ResolveCtx` |
| `project ctx id attr` / `edges ctx id` / `why ctx { id; attr }` | read-only consumers of a `ResolveCtx` |
| `materialize ctx id` / `materializeAll ctx class` / `terminalBind` | the terminal — force `output-modules`, bind via gen-bind |
| `override ctx { id; newDecls }` / `warmResolve ctx { edits }` | intra-eval incremental (topological reverse cone) |
| `classKey ctx id` | the fleet KEY — a conservative reuse-narrowing digest (D8) |

## Delegation — one instrument per sibling

| concern | sibling | theory |
|---|---|---|
| demand fixpoint (runtime order = Nix laziness) | `gen-scope` `eval`/`evalWarm` | Mokhov 2018 §4.1 |
| attribute-dependency topology / condensation / reverse cone | `gen-graph` `condensation`/`reachableFrom`/`dependentsOf`/`coneRank` | Knuth 1968 |
| dirtiness oracle (deferred cross-invocation layer) | `gen-rebuild` `build`/`affectedSet` | Mokhov 2018 rebuilder / RTD 1983 |
| strata fold (Neron D>I>P; `cascade.combine` = the per-field strategy) | `gen-algebra` `record.foldLayersTraced` | Neron et al. 2015 §2 |
| terminal module binding (defunctionalized arg injection) | `gen-bind` `wrapAll` | Reynolds 1972 |
| pure utility base (**transitive only** — each sibling carries its own; the `.lib` takes no direct prelude) | `gen-prelude` | — |

`REFERENCE.md` (in the design-spec repo, `gen-specs/gen-resolve/REFERENCE.md`) maps each op to
the exact lemma it discharges.

## What gen-resolve is *for* (and what it is not)

Two framing guardrails, both grounded in the measured hola fleet analysis
(`~/Documents/papers/hola-architecture/`) — read them before inferring a performance story:

1. **v1's realized value is structure + a stable class KEY — NOT per-host eval speed, and NOT
   (yet) fleet sharing.** The cortex profile shows a per-host evaluation is ~94% intrinsic
   derivation construction / ~6% module-system machinery, single-thread-bound. No resolution
   cleverness moves the 94%; do not read a per-host speedup into gen-resolve. What v1 delivers
   TODAY is *correctness* (HOAG/RAG well-definedness, the two-stratum guarantee) and a stable
   *class KEY*. The fleet class-sharing *payoff* that KEY is built for (collapsing identical
   host-classes across a fleet) is a **measured PoC direction in hola, NOT shipped den
   infrastructure** — the hola Plane-2a/2b work is on unmerged feature branches / gist PoCs
   (den `feat/s1-per-sid-hostconfig`, `feat/s2-pipe-reads`, as of 2026-07-01). So the DESIGN is
   grounded in the hola *analysis*; the fleet *lever* is a trajectory the key enables, not a
   realized capability. Don't cite gen-resolve as *delivering* fleet sharing.

1. **Three sharing layers — know which one this is.**

   - **(a) intra-eval attribute memo** — `gen-scope`'s `lib.fix`; free, already happening.
   - **(b) cross-invocation resolved-value reuse** — keyed on `classKey`; the cache + byte-identity
     gate are DEFERRED (the cross-invocation layer, hola Plane-2b — still PoC/unmerged in den).
     v1 ships the key only.
   - **(c) `evalModules` config-snapshot cross-scope sharing** — **hola owns this** (vendor-and-own,
     byte-identical). gen-resolve sits **upstream of `evalModules`**: it produces per-node module
     *lists* (`terminalBind`) and shares at the *resolution* layer, not the config-snapshot layer.

## The static schedule (owned) vs runtime order (delegated)

`resolve` forces `buildSchedule` once (D12, carried edit-invariant in the `ResolveCtx`). It:

- builds the Knuth attribute-dependency graph (`a → b` iff `b ∈ readsAttrs a`);
- runs the **Vogt well-definedness gate**: a cyclic SCC is admissible iff every member is a
  declared `circular` attribute (Sloane 2009 iterate-to-fixpoint); otherwise it throws the
  Knuth 1968 circularity error;
- runs the **two-stratum partition assert** (van Antwerpen 2016 §4.3): a `structural` attr's
  read-cone may not reach a `resolution` attr (the `terminal` sink is exempt).

Runtime order is never scheduled by gen-resolve — it is Nix demand inside the delegated fixpoint.

## `override` — intra-eval incremental

`override`/`warmResolve` mark the **topological reverse cone** (`gen-graph.dependentsOf`) dirty
and re-fold via `gen-scope.evalWarm`, serving the clean complement from the cold prior. The reverse
cone is a **sound over-approximation** of the RTD 1983 AFFECTED set (RTD's AFFECTED is the cone
*minus* the unchanged-value nodes) — **not** the exact-AFFECTED hash-cutoff. That choice is
deliberate and fleet-grounded: exact-AFFECTED's detection pass would force (hash) the dominant
per-host spine and `evalWarm` would force it again — a literal 2× of the dominant cost intra-eval
(the hola E3c cross-scope-sharing NO-GO shape). The hash-cutoff refinement pays off only
cross-invocation, where it moves to the deferred layer. **Edge-moves (topology changes) error in
v1** (D14); editing a non-root node also throws. `builtCtx` (the `gen-rebuild` oracle) is retained
as a LAZY field — the deferred cross-eval hook — and is never forced by v1's
`resolve`/`materialize`/`override`, so a cyclic node graph still resolves.

> **Soundness (c).** Warm-serving is sound only if `declaredEdges` **over-declares** every cross-node
> read (consumer→producer). Under-declare, and a consumer outside the declared cone is served its
> *stale* prior value on override — `ci/tests/override-cross-node.nix` witnesses both branches.

> **`warmResolve` shape.** The design spec lists `warmResolve ctx { changedIds }`, but a *pure*
> batch override cannot carry the data-changes without their payload — v1 therefore takes
> `{ edits }` (the `{ id = newDecls }` map); `changedIds = attrNames edits`.

## `terminalBind` and `evalModules`

`terminalBind = (gen-bind.wrapAll args).all` — the wrapped config modules **plus** the collision
validators. The DP5 conformance oracle drives that full `.all` set through a real `lib.evalModules`
and asserts the resolved config is byte-identical to the equivalent flat module list. This relies
on gen-bind emitting an **evalModules-safe** validator (a lazy `config.warnings` contribution, not
an eager `builtins.seq` that would force `config._module.args` at module-collection time and
recurse); that fix landed in gen-bind alongside this library.

## Develop

```sh
nix flake check ./ci                      # nix-unit suite + purity + the evalModules oracle
nix build ./ci#formatter.x86_64-linux     # then run ./result/bin/* . to format
nix eval ./examples/dag#result.ok         # §5 example surfaces (dag / nta / fleet)
```

Pre-publish, the examples resolve gen-resolve locally: append
`--override-input gen-resolve <path-to-this-repo>`.

The library (`lib/`) is `nixpkgs.lib`-free (enforced by `ci/tests/purity.nix`); nixpkgs is pulled
only in `ci/` for the test harness and the DP5 `evalModules`-equivalence oracle.

## License

MIT — see `LICENSE`.
