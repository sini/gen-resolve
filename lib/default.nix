# gen-resolve public API. Class B — 5 gen siblings (scope/graph/rebuild/algebra/bind). gen-prelude
# is only a TRANSITIVE dep (each sibling carries its own); the .lib surface takes no direct prelude.
# Function <=> deps (convention §8): this file has deps, so it is a function of named VALUES.
#
# gen-resolve is the CONDUCTOR — it owns ONLY the static attribute-dependency schedule
# (schedule.nix) and the cold/warm fold (resolve.nix / override.nix); every instrument is a
# HARD-boundary delegation to a pure sibling (scope demand fixpoint, graph topology, rebuild
# dirtiness oracle, algebra strata fold, bind terminal). Runtime order is demand — Nix
# laziness inside scope.eval's lib.fix (Mokhov 2018 §4.1); gen-resolve never re-orders thunks.
{
  scope,
  graph,
  rebuild,
  algebra,
  bind,
}:
let
  equation = import ./equation.nix { inherit scope algebra; };
  schedule = import ./schedule.nix { inherit graph; };
  resolveM = import ./resolve.nix { inherit scope rebuild schedule; };
  contract = import ./contract.nix; # bare value (dep-free)
  materialize = import ./materialize.nix { inherit bind; };
  override = import ./override.nix { inherit scope graph rebuild; };
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
  inherit (override) override warmResolve;
  inherit (classkey) classKey;
  # internal, `_`-prefixed — exposed for the schedule tests (Task 2/3); not part of the public surface
  _buildSchedule = schedule.buildSchedule;
  _scheduleWith = schedule.scheduleWith;
  _trackedAttrs = resolveM.trackedAttrs;
}
