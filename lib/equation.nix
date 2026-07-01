# The equation constructors — the ONLY authoring surface (design §5).
# Each yields an Equation = { name; kind; compute :: self -> id -> value; readsAttrs; stratum }.
# THEORY: attr = Knuth 1968 semantic equation; nta = Vogt 1989 §2 node-spawning attribute;
#         cascade = Neron et al. 2015 §2 D>I>P strata fold; reference = Hedin 2000 reference attribute.
{ scope, algebra }:
let
  # DP1 (hybrid-B): stratum derived from kind; synthesized carries an explicit label (default structural, over-declare-safe).
  stratumOf =
    kind: explicit:
    if explicit != null then
      explicit
    else if kind == "nta" || kind == "inherited" then
      "structural"
    else if kind == "cascade" || kind == "reference" || kind == "circular" then
      "resolution"
    else
      "structural"; # synthesized default — checked, so imports reading resolution is caught

  mk =
    {
      name,
      kind,
      compute,
      readsAttrs,
      stratum ? null,
    }:
    {
      inherit
        name
        kind
        compute
        readsAttrs
        ;
      stratum = stratumOf kind stratum;
    };
in
{
  # Primitive: compute + readsAttrs both explicit (compute is opaque -> nothing to infer).
  attr =
    {
      name,
      kind,
      compute,
      readsAttrs,
      stratum ? null,
    }:
    mk {
      inherit
        name
        kind
        compute
        readsAttrs
        stratum
        ;
    };

  # Vogt 1989 NTA: spawn materializes child scope nodes; structural, reads own decls (no attr deps).
  nta =
    { name, spawn }:
    mk {
      inherit name;
      kind = "nta";
      compute = spawn;
      readsAttrs = [ ];
    };

  # Neron cascade: fold layered strata in scope-graph edge order (self->imports->parent), LAST wins.
  # combine is shadow (D6, associative-only); commutative/idempotent combines are a correctness regression.
  cascade =
    {
      name,
      channel,
      strata ? { },
      combine ? scope.shadow,
    }:
    assert
      (builtins.isFunction combine)
      || throw "gen-resolve.cascade: combine must be a function (shadow-cascade); 'semilattice-set' is reserved and rejected (design §8 D6)";
    mk {
      inherit name;
      kind = "cascade";
      readsAttrs = [ "imports" ]; # neron traversal reads import edges
      compute =
        self: id:
        let
          # collect this channel's per-node layers along the neron contract, least-specific last
          layers = scope.collectionAttr {
            traverse = "neron";
            extract = self': id': (strata.${id'} or (self'.node id').decls.${channel} or null);
            combine = a: b: a ++ b; # accumulate layer LIST; precedence applied by foldLayersTraced
          } self id;
          n = builtins.length layers;
        in
        (algebra.record.foldLayersTraced {
          # neron gives self-first; foldLayersTraced wants least-specific-first -> reverse
          layers = builtins.foldl' (acc: x: [ x ] ++ acc) [ ] layers;
          layerNames = builtins.genList (i: "layer-${toString i}") n;
        }).value;
    };

  # Hedin 2000 reference attribute: query across includes (forward) / neededBy (reverse).
  reference =
    {
      name,
      select,
      target ? "includes",
    }:
    mk {
      inherit name;
      kind = "reference";
      readsAttrs = [ "imports" ]; # scope.query reads import edges
      compute = scope.query { dataFilter = select; };
    };

  inherit stratumOf;
}
