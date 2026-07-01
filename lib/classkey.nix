# The fleet KEY (design §10, D8) — v1 ships the key ONLY, not the cross-invocation cache/gate.
# Generalized: "stable digest of a consumer-designated attribute's resolved value" (domain-agnostic).
#
# CONSERVATIVE KEY, NOT A SOUNDNESS PROOF (hola E3c-C1 two-layer model). classKey NARROWS reuse
# candidates; it does NOT prove two nodes are interchangeable. Keying cross-scope/cross-invocation
# reuse on it is sound ONLY when the designated attribute is the COMPLETE determinant of the reused
# output — the reused region must be def-disjoint from every per-scope delta AND fixpoint-closed
# (reads no per-scope-varying path). No static key is provably complete in general, so any consumer
# reusing on classKey MUST back it with a BYTE-IDENTITY GATE (drvPath equality of the materialized
# output) as the total correctness oracle. Key narrows; gate decides. (Cache + gate = deferred, §12.)
#
# Dep-free -> bare value (convention §8): the digest is 100% builtins, so this advertises no
# dependency contract (previously took an unused `{ prelude }`).
let
  # Deep-sanitize before digesting: replace every function with a stable sentinel, keep all other
  # structure. builtins.toJSON THROWS on a bare function; a raw digest would either crash or (via a
  # blanket fallback) false-collide two distinct function-bearing values. Recursing preserves every
  # non-function distinction, so the sentinel only conflates the un-digestible leaves themselves.
  # CAVEAT: assumes a FINITE value (the intended resolved-aspects key data). A self-referential
  # attrset (`let x = { a = x; }; in x`) would diverge, as would toJSON itself; the byte-identity gate
  # (which the key must be backed by) is the real oracle for such values — the key only narrows.
  sentinel = "<gen-resolve/classKey:function>";
  sanitize =
    v:
    if builtins.isFunction v then
      sentinel
    else if builtins.isList v then
      map sanitize v
    else if builtins.isAttrs v then
      builtins.mapAttrs (_: sanitize) v
    else
      v;
in
{
  classKey =
    ctx: id:
    let
      v = ctx.eval.get id "resolved-aspects"; # default key attribute; consumer may digest another via project
    in
    builtins.hashString "sha256" (builtins.toJSON (sanitize v)); # toJSON captures resolved arg-shape (D8)
}
