# gen-resolve public API. Class B — 4 gen siblings (scope/graph/algebra/bind). gen-prelude
# is only a TRANSITIVE dep (each sibling carries its own); the .lib surface takes no direct prelude.
# A file with deps is a function of named VALUES; a dep-free one is a bare value.
#
# gen-resolve owns the static attribute-dependency schedule (schedule.nix) and the authoring
# vocabulary the schedule is built out of; every instrument is a HARD-boundary delegation to a pure
# sibling (graph topology, algebra strata fold, bind terminal).
#
# THE WARM FOLD HAS LEFT. `override` and `warmResolve` are `gen-memo`'s `warmOverride` and
# `warmResolve`, together with the override cone that decided them: deciding what may be reused from
# a prior evaluation is the incremental plane's whole concern, and it was being answered here from a
# DECLARED stratum that a derived classifier supersedes. `stratumOf` survives that supersession in
# its OTHER role — assigning the strata the schedule orders — and travels with `schedule.nix`
# wherever the ordering work lands; it is the warm-servability role alone that died.
#
# AND THE COLD FOLD HAS LEFT TOO. It is `gen-scope`'s `foldEquations`, which takes a schedule as an
# argument and reads its equations off it: the fold was always the evaluator's CALLER, and the two
# calls it made across this boundary are local ones there. `_scheduleWith` is the producer of the
# value that entry now takes, which is why a caller of the fold still reaches for this library.
#
# THE INCREMENTAL PLANE IS NOT A DEPENDENCY OF THIS LIBRARY. Building a memo context here would
# install the plane inside the thing it is defined against, so a caller holding both composes it.
#
# WHAT ELSE IS NOT HERE, so its absence is not read as an oversight: the static schedule's
# destination is the query-gate home. That disposition is settled; the landing is not this change.
{
  scope,
  graph,
  algebra,
  bind,
}:
let
  equation = import ./equation.nix { inherit scope algebra; };
  schedule = import ./schedule.nix { inherit graph; };
  contract = import ./contract.nix; # bare value (dep-free)
  materialize = import ./materialize.nix { inherit bind; };
  classkey = import ./classkey.nix; # bare value (dep-free)
in
# curated inherit: hide internal helpers, group the surface
{
  inherit (equation)
    attr
    nta
    cascade
    reference
    ;
  inherit (contract) why;
  inherit (materialize) materialize materializeAll terminalBind;
  inherit (classkey) classKey;
  # internal, `_`-prefixed — exposed for the schedule tests; not part of the public surface
  _buildSchedule = schedule.buildSchedule;
  _scheduleWith = schedule.scheduleWith;
}
