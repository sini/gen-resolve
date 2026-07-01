# cascade `combine` is a REAL per-field foldLayersTraced strategy, not an inert param:
# "replace" (shadow/default) last-wins per field; "append" concatenates list-valued fields
# across every layer. The two strategies give DIFFERENT results over the same layered channel.
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    attr
    cascade
    resolve
    project
    ;
  # scope hierarchy leaf -> mid -> base (parent chain; neron walks up it)
  roots = genScope.buildNodes {
    parentGraph = genScope.path [
      "leaf"
      "mid"
      "base"
    ];
    decls = {
      leaf.opts = {
        name = "leaf";
        flags = [ "leaf" ];
      };
      mid.opts.flags = [ "mid" ];
      base.opts = {
        name = "base";
        flags = [ "base" ];
      };
      # a list-only channel so the uniform "append" strategy is well-typed on every field
      leaf.tagsrec.items = [ "leaf" ];
      mid.tagsrec.items = [ "mid" ];
      base.tagsrec.items = [ "base" ];
    };
    types = {
      leaf = "host";
      mid = "host";
      base = "host";
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
    opts = cascade {
      name = "opts";
      channel = "opts";
      combine = "replace";
    };
    tagslist = cascade {
      name = "tagslist";
      channel = "tagsrec";
      combine = "append";
    };
  };
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent = id: roots.${id}.parent or null;
  };
in
{
  flake.tests.cascade = {
    # replace: most-specific layer wins per field (leaf), least-specific field survives
    test-combine-replace = {
      expr = project ctx "leaf" "opts";
      expected = {
        name = "leaf";
        flags = [ "leaf" ];
      };
    };
    # append: the SAME layered channel concatenates across every layer (proves combine bites)
    test-combine-append = {
      expr = (project ctx "leaf" "tagslist").items;
      expected = [
        "base"
        "mid"
        "leaf"
      ];
    };
    # D6: a commutative/idempotent strategy is rejected at registration
    test-combine-rejects-semilattice = {
      expr =
        (builtins.tryEval (cascade {
          name = "x";
          channel = "x";
          combine = "semilattice-set";
        })).success;
      expected = false;
    };
  };
}
