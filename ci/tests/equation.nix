{ lib, genResolve, ... }:
let
  inherit (genResolve)
    attr
    nta
    cascade
    reference
    ;
in
{
  flake.tests.equation = {
    # Knuth 1968 semantic equation — attr takes readsAttrs explicitly (compute opaque)
    test-attr-shape = {
      expr =
        let
          e = attr {
            name = "x";
            kind = "synthesized";
            compute = self: id: 1;
            readsAttrs = [ "y" ];
          };
        in
        {
          inherit (e)
            name
            kind
            readsAttrs
            stratum
            ;
        };
      expected = {
        name = "x";
        kind = "synthesized";
        readsAttrs = [ "y" ];
        stratum = "structural";
      };
    };
    # DP1: synthesized honours explicit stratum (terminal sink)
    test-attr-terminal = {
      expr =
        (attr {
          name = "output-modules";
          kind = "synthesized";
          compute = self: id: { };
          readsAttrs = [ ];
          stratum = "terminal";
        }).stratum;
      expected = "terminal";
    };
    # DP1: circular attr -> resolution stratum, may sit in an SCC
    test-attr-circular-stratum = {
      expr =
        (attr {
          name = "resolved-aspects";
          kind = "circular";
          compute = self: id: { };
          readsAttrs = [ "resolved-aspects" ];
        }).stratum;
      expected = "resolution";
    };
    # Vogt 1989 NTA — nta auto-populates readsAttrs (structural, reads own decls only)
    test-nta = {
      expr =
        let
          e = nta {
            name = "children";
            spawn = self: id: { "${id}/c" = { }; };
          };
        in
        {
          inherit (e) kind stratum readsAttrs;
        };
      expected = {
        kind = "nta";
        stratum = "structural";
        readsAttrs = [ ];
      };
    };
    # Neron cascade — auto readsAttrs ["imports"] (neron traversal), resolution stratum
    test-cascade = {
      expr =
        let
          e = cascade {
            name = "settings";
            channel = "settings";
          };
        in
        {
          inherit (e) kind stratum readsAttrs;
        };
      expected = {
        kind = "cascade";
        stratum = "resolution";
        readsAttrs = [ "imports" ];
      };
    };
    # D6 — commutative/idempotent combine rejected at registration
    test-cascade-rejects-semilattice = {
      expr =
        (builtins.tryEval (cascade {
          name = "s";
          channel = "s";
          combine = "semilattice-set";
        })).success;
      expected = false;
    };
    # Hedin reference — auto readsAttrs ["imports"], resolution stratum
    test-reference = {
      expr =
        (reference {
          name = "provides";
          select = n: n.decls.p or null;
          target = "includes";
        }).stratum;
      expected = "resolution";
    };
  };
}
