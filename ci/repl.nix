# gen-resolve REPL — all exports in scope. Constructs the lib from the standalone
# default.nix (siblings pinned via ../flake.lock), plus nixpkgs `lib` for scratch use.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  genResolve = import ../. { };
in
{
  inherit (nixpkgs) lib;
  inherit genResolve;
}
// genResolve
