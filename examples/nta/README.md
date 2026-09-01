# gen-resolve example — higher-order NTA (§5.2)

A `cluster` kind whose registered **spawn** (a non-terminal attribute, Vogt 1989
§2) produces one `service` node per replica *mid-fold*: the node grammar grows
during evaluation and each spawned node carries its own attributes. The expansion
is declared on the kind it expands from — `mkKind { below = [ "service" ]; spawns.service = …; }` — so the produced kind is a registered name below its
host's own and the descent is settled before anything fires; the builder does not
write its child's `type`, because the substrate stamps that from the key.

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

| library           | symbols                  |
| ----------------- | ------------------------ |
| `gen-resolve.lib` | `attr`, `nta`, `resolve` |
| `gen-scope.lib`   | `buildNodes`             |

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
