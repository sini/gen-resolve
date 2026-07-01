# Consumers of a ResolveCtx (design §6). Dep-free -> bare value.
let
  project =
    ctx: id: attr:
    ctx.eval.get id attr;
  edges = ctx: id: (ctx.trace.${id} or { deps = [ ]; }).deps;
  # why :: ResolveCtx -> { id; attr } -> [Dep]  (design §6). NAME-only static provenance over the
  # declared trace: the declared node-edges x the attr's readsAttrs. (Cutoff-aware WhyResult is
  # gen-rebuild.why over a BuiltCtx — deferred with the cross-eval layer; see the open items note.)
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
  inherit project edges why;
}
