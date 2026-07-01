# §5.3 — the den fleet surface. Hosts resolve an aspect set (gen-aspects.flatten), read a
# sibling's data across an `includes` edge (Hedin reference), collapse identical host-classes
# under one classKey (D8), and an `override` of one host re-derives only its reverse cone —
# every other host keeps its prior resolved value.
{
  genResolve,
  genScope,
  genAspects,
  lib,
}:
let
  inherit (genResolve)
    attr
    reference
    resolve
    project
    classKey
    override
    ;

  # per-class aspect trees -> flat path-key registries (gen-aspects.flatten)
  classAspects = {
    web.web = {
      name = "web";
      nginx = {
        name = "nginx";
      };
    };
    db.db = {
      name = "db";
      postgres = {
        name = "postgres";
      };
    };
  };
  flatKeys =
    cls: lib.sort (a: b: a < b) (builtins.attrNames (genAspects.flatten classAspects.${cls}));
  # gen-aspects identity.key — path key for an aspect
  nginxIdentity = genAspects.key {
    name = "nginx";
    meta.aspect-chain = [ "web" ];
  };

  roots = genScope.buildNodes {
    importGraph = genScope.edge "web1" "db1"; # web1 includes db1 (cross-host reference edge)
    decls = {
      web1.class = "web";
      web2.class = "web"; # same class as web1 -> classKey collapses them
      db1 = {
        class = "db";
        role = "database"; # a field only db1 declares -> surfaces across the includes edge
      };
    };
    types = {
      web1 = "host";
      web2 = "host";
      db1 = "host";
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
    resolved-aspects = attr {
      name = "resolved-aspects";
      kind = "synthesized";
      stratum = "resolution";
      readsAttrs = [ ];
      compute = self: id: flatKeys (self.node id).decls.class;
    };
    # Hedin 2000 reference over includes: resolves to the nearest binding — web1 has no local
    # `role`, so the value surfaces from the included db1 (the cross-host read).
    included-role = reference {
      name = "included-role";
      select = n: n.decls.role or null;
      target = "includes";
    };
  };
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent = _: null;
  };

  # override web2's class web -> db: only web2 (its own cone) re-derives
  ctx' = override ctx {
    id = "web2";
    newDecls = {
      class = "db";
    };
  };

  checks = {
    # D8 — identical resolved aspects collapse to one key; a different class splits
    identical-class-collapses = classKey ctx "web1" == classKey ctx "web2";
    different-class-splits = classKey ctx "web1" != classKey ctx "db1";
    # gen-aspects.flatten / identity.key
    aspect-flatten-keys =
      flatKeys "web" == [
        "web"
        "web/nginx"
      ];
    aspect-identity-key = nginxIdentity == "web/nginx";
    # cross-host read: web1 sees db1's `role` across the includes edge (Hedin reference)
    cross-host-includes-read = project ctx "web1" "included-role" == "database";
    # override re-derives the target's cone...
    override-reclasses-target = project ctx' "web2" "resolved-aspects" == flatKeys "db";
    override-collapses-to-db = classKey ctx' "web2" == classKey ctx' "db1";
    # ...and leaves every non-cone host's prior value byte-identical
    override-keeps-noncone =
      project ctx' "web1" "resolved-aspects" == project ctx "web1" "resolved-aspects";
  };
in
{
  inherit checks;
  keys = {
    web1 = classKey ctx "web1";
    web2 = classKey ctx "web2";
    db1 = classKey ctx "db1";
  };
  ok = builtins.all (v: v) (builtins.attrValues checks);
}
