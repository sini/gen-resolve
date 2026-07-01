# The terminal (design §8-step5). DP2: gen-resolve only FORCES output-modules; the bind lives in the
# consumer's equation via terminalBind. THEORY: gen-bind = Reynolds 1972 defunctionalized arg injection;
# deferredModule class content = Lorenzen 2025 inspectable lazy constructor (Informed-by).
{ bind }:
let
  terminalBind =
    args@{
      modules,
      bindings,
      ...
    }:
    (bind.wrapAll args).all; # .all = wrapped modules ++ collision validators
in
{
  inherit terminalBind;
  materialize = ctx: id: ctx.eval.get id "output-modules"; # forces the ONLY gen-bind site
  materializeAll =
    ctx: type: builtins.mapAttrs (id: _: ctx.eval.get id "output-modules") (ctx.eval.nodesOfType type);
}
