#!/usr/bin/env bash
# AMD cards: avatarmanz's VIctory-7900XTX with its own settings.
#
#   ./run-amd.sh <game folder, or the title's exe> [more `victory run` options]
#
# The same as run.sh with VICTORY_BUILD=victory-7900xtx (see run.sh and
# docs/linux-proton.md).
export VICTORY_BUILD=victory-7900xtx
exec "$(dirname "$0")/run.sh" "$@"
