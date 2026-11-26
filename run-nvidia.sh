#!/usr/bin/env bash
# NVIDIA cards: fxceless's victory-fork, the reference build for NVIDIA.
#
#   ./run-nvidia.sh <game folder, or the title's exe> [more `victory run` options]
#
# The same as run.sh with VICTORY_BUILD=victory-fork (see run.sh and
# docs/linux-proton.md).
export VICTORY_BUILD=victory-fork
exec "$(dirname "$0")/run.sh" "$@"
