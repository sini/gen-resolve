# The cross-node warm-serve path (previously untested). A `consumer` node reads a `producer`
# node's RESOLUTION attribute. Override soundness holds iff declaredEdges over-declares the
# cross-node read (soundness condition (c)):
#   - declaredEdges declares consumer->producer  => override re-derives consumer (byte-identical)
#   - declaredEdges empty                          => consumer is served its STALE prior (witness)
# This is the explicit demonstration of the over-declaration contract override.nix documents.
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    attr
    resolve
    override
    project
    ;
  mkRoots =
    v:
    genScope.buildNodes {
      importGraph = genScope.edge "consumer" "producer"; # consumer includes producer
      decls = {
        producer.v = v;
        consumer = { };
      };
      types = {
        producer = "host";
        consumer = "host";
      };
    };
  eqs = {
    imports = attr {
      name = "imports";
      kind = "synthesized";
      stratum = "structural";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.__edges.I or [ ];
    };
    p-val = attr {
      name = "p-val";
      kind = "synthesized";
      stratum = "resolution";
      readsAttrs = [ ];
      compute = self: id: (self.node id).decls.v or 0;
    };
    # a RESOLUTION attr that reads ANOTHER node's resolution attr (the cross-node read)
    sees = attr {
      name = "sees";
      kind = "synthesized";
      stratum = "resolution";
      readsAttrs = [ "p-val" ];
      compute = self: id: if id == "consumer" then (self.get "producer" "p-val") + 100 else 0;
    };
  };
  declaredEdges = id: if id == "consumer" then [ "producer" ] else [ ];

  # (1) declaredEdges present -> override is byte-identical to a fresh resolve
  ctxD = resolve {
    roots = mkRoots 1;
    equations = eqs;
    parseParent = _: null;
    inherit declaredEdges;
  };
  ctxD' = override ctxD {
    id = "producer";
    newDecls = {
      v = 9;
    };
  };
  freshD = resolve {
    roots = mkRoots 9;
    equations = eqs;
    parseParent = _: null;
    inherit declaredEdges;
  };

  # (2) declaredEdges empty -> consumer is NOT in producer's cone -> served stale
  ctxN = resolve {
    roots = mkRoots 1;
    equations = eqs;
    parseParent = _: null;
    declaredEdges = _: [ ];
  };
  ctxN' = override ctxN {
    id = "producer";
    newDecls = {
      v = 9;
    };
  };
in
{
  flake.tests.override-cross-node = {
    # producer itself always re-derives (it is the edited node, in the dirty set)
    test-producer-rederives = {
      expr = project ctxN' "producer" "p-val";
      expected = 9;
    };
    # declared cross-edge -> consumer re-derives to the fresh value (byte-identical)
    test-declared-consumer-rederives = {
      expr = project ctxD' "consumer" "sees";
      expected = 109;
    };
    test-declared-byte-identical = {
      expr = project ctxD' "consumer" "sees" == project freshD "consumer" "sees";
      expected = true;
    };
    # UNDER-DECLARED cross-edge -> consumer is served its STALE prior (100 + old v=1), NOT 109.
    # Witnesses soundness condition (c): declaredEdges MUST over-declare cross-node reads.
    test-undeclared-serves-stale = {
      expr = project ctxN' "consumer" "sees";
      expected = 101;
    };
  };
}
