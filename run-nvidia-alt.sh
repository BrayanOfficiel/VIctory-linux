#!/usr/bin/env bash
# NVIDIA cards, the alternative: VIctory-7900XTX with VIctory-NVIDIA's settings.
#
#   ./run-nvidia-alt.sh <game folder, or the title's exe> [more `victory run` options]
#
# The same as run.sh with VICTORY_BUILD=nvidia-alt (see run.sh and
# docs/linux-proton.md).
export VICTORY_BUILD=nvidia-alt
exec "$(dirname "$0")/run.sh" "$@"
