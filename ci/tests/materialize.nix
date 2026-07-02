# Task 6 — the terminal + the DP5 evalModules-equivalence oracle. nixpkgs `lib` is used
# ONLY here (the oracle); the library (../lib) stays nixpkgs-free (purity.nix enforces).
#
# DP5: a materialized module set (terminalBind -> gen-bind wrapAll -> .all) fed to a REAL
# lib.evalModules produces the SAME resolved config as the equivalent flat module list fed to
# lib.evalModules directly. Shape mirrors den + the gen-bind evalModules-equivalence convention:
# the option DECLARATION lives in a base module (in den, the NixOS module set); gen-resolve emits
# the config-SETTING module, whose external `host` binding is injected by terminalBind (Reynolds
# §5 closure-based partial-application binding, NOT defunctionalization). The bound module takes
# `{ host, config, ... }` so gen-bind takes the
# partial-application wrapper path (the fully-applied `allMatched` path is for arg-only modules).
{
  lib,
  genResolve,
  genScope,
  ...
}:
let
  inherit (genResolve)
    resolve
    materialize
    materializeAll
    terminalBind
    ;
  roots = genScope.buildNodes {
    decls = {
      h = { };
    };
    types = {
      h = "nixos";
    };
  };
  # base module set (den: nixpkgs) — declares the option + `warnings` (which the gen-bind
  # collision validator carried in `.all` contributes to); not gen-resolve's output
  optionsBase =
    { lib, ... }:
    {
      options.hostName = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      options.warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  # gen-resolve-emitted config module: sets the option from the injected `host` binding
  boundModule =
    { host, config, ... }:
    {
      config.hostName = host.hostName;
    };
  # equivalent flat config module (value set directly, no binding)
  flatModule =
    { config, ... }:
    {
      config.hostName = "igloo";
    };
  eqs = {
    settings = genResolve.attr {
      name = "settings";
      kind = "synthesized";
      readsAttrs = [ ];
      compute = self: id: { hostName = "igloo"; };
    };
    output-modules = genResolve.attr {
      name = "output-modules";
      kind = "synthesized";
      stratum = "terminal";
      readsAttrs = [ "settings" ];
      compute = self: id: {
        nixos = terminalBind {
          modules = [ boundModule ];
          bindings = {
            host = self.get id "settings";
          };
        };
      };
    };
  };
  ctx = resolve {
    inherit roots;
    equations = eqs;
    parseParent = _: null;
  };
  out = materialize ctx "h";
  # out.nixos = terminalBind -> wrapAll .all = wrapped config module ++ collision validator.
  # Feeding the WHOLE .all (validator included) to a real evalModules exercises the gen-bind
  # lazy-validator fix; forcing config.warnings proves the validator is consumed, not just ignored.
  evaluated = lib.evalModules { modules = [ optionsBase ] ++ out.nixos; };
  viaResolve = evaluated.config.hostName;
  viaNixpkgs =
    (lib.evalModules {
      modules = [
        optionsBase
        flatModule
      ];
    }).config.hostName;
in
{
  flake.tests.materialize = {
    test-materialize-classes = {
      expr = builtins.attrNames out;
      expected = [ "nixos" ];
    };
    # materializeAll sweeps nodesOfType (per-node terminal)
    test-materialize-all = {
      expr = builtins.attrNames (materializeAll ctx "nixos");
      expected = [ "h" ];
    };
    # DP5 central gate: terminal binding path == equivalent flat module list, through real evalModules
    test-evalmodules-equivalence = {
      expr = viaResolve;
      expected = viaNixpkgs;
    };
    # the collision validator carried in .all is evalModules-safe and reports no collision
    test-terminal-all-validator-safe = {
      expr = evaluated.config.warnings;
      expected = [ ];
    };
  };
}
