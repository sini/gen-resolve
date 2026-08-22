# Consumers of a ResolveCtx (design §6). Dep-free -> bare value.
#
# TWO CONSUMERS RETIRED HERE AND THEIR SUCCESSORS ARE THE SUBSTRATE'S OWN. `project` was
# `ctx: id: attr: ctx.eval.get id attr` — a currying re-spelling of the facade's `get`, and the same
# function reached by a second path rather than a construct of its own, so nothing was owed at the
# destination and callers read `ctx.eval.facade.get id attr` directly. `edges` was a projection of
# `ctx.trace.<id>.deps`, which the seal publishes itself.
#
# ★ `edges` SURVIVES AS AN INTERNAL BINDING AND THAT IS DELIBERATE. `why` is defined over it, and
# what the binding carries beyond the field read is the `or { deps = [ ]; }` default — an id the
# fold never saw answers the empty relation instead of aborting. Pointing `why` at
# `ctx.trace.<id>.deps` would hand it the seal's refusal for that case, which is an uncatchable
# abort rather than a thrown value, and would change a live export's observable behaviour under
# cover of retiring a different one. The default stays exactly where its one reader is.
let
  edges = ctx: id: (ctx.trace.${id} or { deps = [ ]; }).deps;
  # why :: ResolveCtx -> { id; attr } -> [Dep]  (design §6). NAME-only static provenance over the
  # declared trace: the declared node-edges x the attr's readsAttrs. (Cutoff-aware WhyResult is
  # the plane's `why` over a BuiltCtx — deferred with the cross-eval layer; see the open items note.)
  why =
    ctx:
    { id, attr }:
    let
      reads = (ctx.equations.${attr} or { readsAttrs = [ ]; }).readsAttrs;
    in
    builtins.concatMap (
      d:
      map (a: {
        id = d;
        attr = a;
      }) reads
    ) (edges ctx id);
in
{
  inherit why;
}
