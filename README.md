# gen-resolve

Pure-Nix, nixpkgs-lib-free, demand-driven **higher-order reference-attribute-grammar
evaluator** — `resolve` / `materialize` over algebraic scope graphs.

gen-resolve is the *conductor*: it owns ONLY the static attribute-dependency schedule
(Knuth 1968 + Vogt 1989 HOAG well-definedness) and the cold/warm fold into the demand
fixpoint. Every instrument is a hard-boundary delegation to a pure sibling:

| concern | sibling |
|---|---|
| demand fixpoint (runtime order = Nix laziness, Mokhov 2018 §4.1) | `gen-scope` |
| attribute-dependency topology / condensation / reverse cone | `gen-graph` |
| dirtiness oracle (deferred cross-invocation layer) | `gen-rebuild` |
| strata fold (Neron D>I>P, last-wins) | `gen-algebra` |
| terminal module binding (Reynolds 1972 defunctionalization) | `gen-bind` |
| pure utility base | `gen-prelude` |

> Full API, delegation table, and the THEORY→op map: see `REFERENCE.md` (Task 12).

## Status

v1 in progress — see `gen-specs/gen-resolve/gen-resolve-phase0-tracker.md`.

## Develop

```sh
nix flake check ./ci          # nix-unit suite + purity + evalModules oracle
nix build ./ci#formatter.x86_64-linux
```

The library (`lib/`) is nixpkgs-lib-free (enforced by `ci/tests/purity.nix`); nixpkgs is
pulled only in `ci/` for the test harness and the DP5 evalModules-equivalence oracle.
