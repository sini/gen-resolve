# gen-resolve example — higher-order NTA (§5.2)

A `cluster` node whose `derived-children` **NTA** (non-terminal attribute, Vogt
1989 §2) spawns one `service` node per replica *mid-fold*: the node grammar grows
during evaluation and each spawned node carries its own attributes.

- **Grammar grows mid-fold** — the single declared `cluster` root resolves to
  four nodes (`cluster` + three spawned `service` nodes). The spawn is a real
  higher-order production, not a pre-enumerated list.
- **Typed spawned nodes** — every spawned child is a first-class, typed grammar
  node (`type == "service"`) reachable through the fold via `ctx.eval.node`.
- **Per-node synthesized attributes** — each spawned `service` computes its own
  `port` (`8080 + idx`), so the derived subtree carries independent state.
- **Structural stratum** — `imports` is a `structural`-stratum synthesized
  attribute, resolved before the value stratum that reads `decls.idx`.

## API used (current gen libraries)

| library | symbols |
| --- | --- |
| `gen-resolve.lib` | `attr`, `nta`, `resolve`, `project` |
| `gen-scope.lib` | `buildNodes` |

Every gen flake output is a single `.lib` value (the old callable
`gen-X { inherit lib; }` form is obsolete).

## Run it

```console
$ nix eval .#result.ok
true

$ nix eval .#result.checks --json | jq
```

`result.checks` is an attrset of named booleans (all `true` when green);
`result.ok` is their conjunction. `result.serviceIds` and `result.ports` expose
the three spawned services and their computed ports.

During local development against an unpublished `gen-resolve`, override the pin:

```console
$ nix eval --override-input gen-resolve ../.. .#result.ok
```
