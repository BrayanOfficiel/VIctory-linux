#!/usr/bin/env bash
# The keybinds editor: a picture of the pad with a clickable box per
# binding; press a key while a box is selected and it goes into
# keybinds.conf, hot-reloaded by the running game.
#
#   ./run-editor.sh [path]     # default: keybinds.conf in this folder
#
# The game (run.sh and friends) reads the same file, and the title picks up
# edits within a second of them being written.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if [[ $# -eq 0 && -z "${VICTORY_KEYBINDS:-}" && ! -f "$ROOT/keybinds.conf" ]]; then
    cp "$ROOT/keybinds.example.conf" "$ROOT/keybinds.conf"
    echo "run-editor.sh: started from the example file at $ROOT/keybinds.conf" >&2
fi
exec cargo run -p keybinds-editor --release -- "$@"
