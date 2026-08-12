# gen-resolve public API. Class B — 5 gen siblings (scope/graph/memo/algebra/bind). gen-prelude
# is only a TRANSITIVE dep (each sibling carries its own); the .lib surface takes no direct prelude.
# Function <=> deps (convention §8): this file has deps, so it is a function of named VALUES.
#
# gen-resolve is the CONDUCTOR — it owns the static attribute-dependency schedule (schedule.nix) and
# the COLD fold (resolve.nix); every instrument is a HARD-boundary delegation to a pure sibling
# (scope demand fixpoint, graph topology, the memo plane's reuse decision, algebra strata fold, bind
# terminal). Runtime order is demand — Nix's own laziness inside the evaluator's fixpoint;
# gen-resolve never re-orders thunks.
#
# THE WARM FOLD HAS LEFT. `override` and `warmResolve` are `gen-memo`'s `warmOverride` and
# `warmResolve`, together with the override cone that decided them: deciding what may be reused from
# a prior evaluation is the incremental plane's whole concern, and it was being answered here from a
# DECLARED stratum that a derived classifier supersedes. `stratumOf` survives that supersession in
# its OTHER role — assigning the strata the schedule orders — and travels with `schedule.nix`
# wherever the ordering work lands; it is the warm-servability role alone that died.
#
# WHAT ELSE IS NOT HERE, so its absence is not read as an oversight: the cold fold's own destination
# is the evaluator, and the static schedule's is the query-gate home. Both dispositions are settled;
# neither landing is this change.
{
  scope,
  graph,
  memo,
  algebra,
  bind,
}:
let
  equation = import ./equation.nix { inherit scope algebra; };
  schedule = import ./schedule.nix { inherit graph; };
  resolveM = import ./resolve.nix { inherit scope memo schedule; };
  contract = import ./contract.nix; # bare value (dep-free)
  materialize = import ./materialize.nix { inherit bind; };
  classkey = import ./classkey.nix; # bare value (dep-free)
in
# curated inherit (convention §9): hide internal helpers, group the surface
{
  inherit (equation)
    attr
    nta
    cascade
    reference
    ;
  inherit (resolveM) resolve;
  inherit (contract) project edges why;
  inherit (materialize) materialize materializeAll terminalBind;
  inherit (classkey) classKey;
  # internal, `_`-prefixed — exposed for the schedule tests; not part of the public surface
  _buildSchedule = schedule.buildSchedule;
  _scheduleWith = schedule.scheduleWith;
}
