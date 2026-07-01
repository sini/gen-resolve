# gen-resolve example — den fleet (§5.3)

A small host fleet resolved with `gen-resolve`, showing the four load-bearing
behaviours of the RAG schedule conductor:

- **Aspect resolution** — each host resolves its class into a flat path-key
  registry via `gen-aspects.flatten` / `gen-aspects.key`
  (`web` → `[ "web" "web/nginx" ]`).
- **Cross-host reads** (Hedin 2000 reference) — `web1` includes `db1` over an
  `includes` edge and reads a field (`role`) that only `db1` declares; the value
  surfaces from the included node.
- **Reverse reads / `neededBy`** (Hedin & Magnusson 2003) — `db1` gathers the
  class of every host that imports it, delegated to `gen-scope.queryReverse`.
- **`classKey` collapse (D8)** — hosts with identical resolved aspects collapse
  to one key (`web1` == `web2`); a different class splits.
- **`override` reverse-cone re-derivation** — overriding one host re-derives only
  its reverse cone; every other host keeps its prior resolved value
  byte-identical. A *declared* cross-node read (`web1 → db1`) re-derives soundly
  when the target changes.

## API used (current gen libraries)

| library | symbols |
| --- | --- |
| `gen-resolve.lib` | `attr`, `reference`, `resolve`, `project`, `classKey`, `override` |
| `gen-scope.lib` | `buildNodes`, `edge`, `queryReverse` (internal to `reference`) |
| `gen-aspects.lib` | `flatten`, `key` |

Every gen flake output is a single `.lib` value (the old callable
`gen-X { inherit lib; }` form is obsolete).

## Run it

```console
$ nix eval .#result.ok
true

$ nix eval .#result.checks --json | jq
```

`result.checks` is an attrset of named booleans (all `true` when green);
`result.ok` is their conjunction. `result.keys` exposes the three hosts'
`classKey`s (`web1` and `web2` are identical, `db1` differs).

During local development against an unpublished `gen-resolve`, override the pin:

```console
$ nix eval --override-input gen-resolve ../.. .#result.ok
```
