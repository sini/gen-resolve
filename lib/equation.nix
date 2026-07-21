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

  # foldLayersTraced strategies a cascade may use unconditionally — the associative,
  # non-semilattice merges D6 permits.
  cascadeStrategies = [
    "replace"
    "append"
    "recursive"
  ];
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

  # Neron 2015 cascade: fold layered strata along the neron scope contract (self -> imports
  # -> parent), most-specific LAST. `combine` selects the per-field gen-algebra fold strategy
  # (D13, foldLayersTraced) applied uniformly to every field: "replace" (shadow / last-wins,
  # the default) | "append" (list concat) | "recursive" (deep //) — exactly the associative,
  # non-semilattice merges D6 permits. The commutative/idempotent "semilattice-set" (JSL/ACI
  # set-union) is admitted too, but ONLY when the production declares `acc = true`: ACC (finite
  # height / ascending-chain condition) is undecidable from an arbitrary combine, so it is a
  # declared carrier property, not an inferred one. (foldLayersTraced's `strategies` is the
  # seam — the param is real, not inert; a declared semilattice-set flows straight through.)
  cascade =
    {
      name,
      channel,
      strata ? { },
      combine ? "replace",
      acc ? false,
    }:
    assert
      (builtins.elem combine cascadeStrategies)
      || (combine == "semilattice-set" && acc)
      || throw (
        if combine == "semilattice-set" then
          "gen-resolve.cascade: combine 'semilattice-set' (JSL/ACI) requires a declared ACC/finite-height carrier — set acc = true"
        else
          "gen-resolve.cascade: combine must be replace|append|recursive|semilattice-set (associative, or JSL+ACC)"
      );
    mk {
      inherit name;
      kind = "cascade";
      readsAttrs = [ "imports" ]; # neron traversal reads import edges
      compute =
        self: id:
        let
          # collect this channel's per-node layers along the neron contract (self-first)
          layers = scope.collectionAttr {
            traverse = "neron";
            extract = self': id': (strata.${id'} or (self'.node id').decls.${channel} or null);
            combine = a: b: a ++ b; # collectionAttr accumulator: build the layer LIST
          } self id;
          # neron gives self-first (most-specific first); foldLayersTraced wants least-specific first
          ordered = builtins.foldl' (acc: x: [ x ] ++ acc) [ ] layers;
          # apply the chosen strategy to EVERY field of the merged record (this is where combine bites)
          allKeys = builtins.attrNames (builtins.foldl' (a: l: a // l) { } ordered);
          strategies = builtins.listToAttrs (
            map (k: {
              name = k;
              value = combine;
            }) allKeys
          );
        in
        (algebra.record.foldLayersTraced {
          layers = ordered;
          layerNames = builtins.genList (i: "layer-${toString i}") (builtins.length ordered);
          inherit strategies;
        }).value;
    };

  # Reference attribute across scope edges. target selects the direction:
  #   "includes" (forward) — Hedin 2000 reference attribute: nearest binding across imports.
  #   "neededBy"  (reverse) — Hedin & Magnusson 2003 inter-type declarations: gather over the
  #                nodes that import this one (delegated to gen-scope.queryReverse). Both read
  #                the import graph, hence readsAttrs = ["imports"].
  reference =
    {
      name,
      select,
      target ? "includes",
    }:
    assert
      (builtins.elem target [
        "includes"
        "neededBy"
      ])
      || throw "gen-resolve.reference: target must be \"includes\" (forward) or \"neededBy\" (reverse)";
    mk {
      inherit name;
      kind = "reference";
      readsAttrs = [ "imports" ];
      compute =
        if target == "neededBy" then
          scope.queryReverse { dataFilter = select; } # reverse gather over importers
        else
          scope.query { dataFilter = select; }; # forward nearest-binding
    };

  inherit stratumOf;
}
