#!/usr/bin/env bash
# Builds BackyardSmokeout.rbxlx: Rojo puts in the code, then Lune bakes the map geometry
# into Workspace so you can see the world in Studio before pressing Play.
set -euo pipefail
cd "$(dirname "$0")/.."
rojo build default.project.json -o BackyardSmokeout.rbxlx
lune run scripts/bake-map BackyardSmokeout.rbxlx
