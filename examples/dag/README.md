# gen-resolve example — attribute-DAG cascade (§5.1)

The abstract attribute-DAG surface of `gen-resolve`, showing the two
load-bearing behaviours of the RAG schedule conductor on a bare scope graph
(no `evalModules`, no `nixpkgs`, no aspects):

- **Neron `cascade` channel** — a channel equation folds layered settings
  least-specific-first along the parent chain
  (`default < env < host < policy`, **last wins**). The traversal walks
  `self → direct imports → up the parent chain`, so the cascade collects every
  layer: the most-specific value wins (`x = "policy"`), while fields declared
  only at a mid layer (`y = "host-y"`) or the root (`z = "default-z"`) survive.

- **Static schedule gates** — the schedule is validated *before* any fold:

  - a non-convergent cycle (two `synthesized` equations reading each other) is
    rejected (Knuth 1968 circularity test);
  - a two-stratum partition violation (a `structural` equation reading a
    `resolution`-stratum attribute) is rejected (van Antwerpen 2016 §4.3).

  Both are asserted via `builtins.tryEval` on `_buildSchedule` — the checks
  pass when the malformed schedules *throw*.

## API used (current gen libraries)

| library | symbols |
| --- | --- |
| `gen-resolve.lib` | `attr`, `cascade`, `resolve`, `project`, `_buildSchedule` |
| `gen-scope.lib` | `buildNodes`, `path` |

Every gen flake output is a single `.lib` value (the old callable
`gen-X { inherit lib; }` form is obsolete).

## Run it

```console
$ nix eval .#result.ok
true

$ nix eval .#result.checks --json | jq
```

`result.checks` is an attrset of named booleans (all `true` when green);
`result.ok` is their conjunction. `result.resolved` exposes the resolved
`settings` for the `policy` node (`{ x = "policy"; y = "host-y"; z = "default-z"; }`).

During local development against an unpublished `gen-resolve`, override the pin:

```console
$ nix eval --override-input gen-resolve ../.. .#result.ok
```
