#!/usr/bin/env bash
# AMD cards: corgansm's victory-corgi with its own settings.
#
#   ./run-amd.sh <game folder, or the title's exe> [more `victory run` options]
#
# The same as run.sh with VICTORY_BUILD=victory-corgi (see run.sh and
# docs/linux-proton.md).
export VICTORY_BUILD=victory-corgi
exec "$(dirname "$0")/run.sh" "$@"
