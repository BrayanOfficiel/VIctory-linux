#!/usr/bin/env bash
# Runs a title with VIctory on Linux, under Proton (see docs/linux-proton.md).
#
#   ./run.sh <game folder, or the title's exe> [more `victory run` options]
#
# The release build is made first if it is missing (cargo-xwin). The title's
# watchdog is off unless VICTORY_NO_WATCHDOG says otherwise: a world load
# under Wine can outlast it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "usage: ./run.sh <game folder, or the title's exe> [more victory run options]" >&2
    exit 2
}
[[ $# -ge 1 && "$1" != "-h" && "$1" != "--help" ]] || usage
game="$1"
shift

if [[ -d "$game" ]]; then
    mapfile -t exes < <(find "$game" -maxdepth 1 -type f -iname '*.exe' | sort)
    if [[ ${#exes[@]} -ne 1 ]]; then
        echo "run.sh: ${#exes[@]} .exe files in $game; name the title's exe instead" >&2
        exit 1
    fi
    title="${exes[0]}"
elif [[ -f "$game" ]]; then
    title="$game"
else
    echo "run.sh: no such folder or file: $game" >&2
    exit 1
fi

target="${CARGO_TARGET_DIR:-$ROOT/target}"
exe="$target/x86_64-pc-windows-msvc/release/victory.exe"
if [[ ! -f "$exe" ]]; then
    echo "run.sh: building VIctory (release) first" >&2
    (cd "$ROOT" && XWIN_ACCEPT_LICENSE=1 cargo xwin build --release -p victory --target x86_64-pc-windows-msvc)
fi

export VICTORY_NO_WATCHDOG="${VICTORY_NO_WATCHDOG-1}"
VICTORY_EXE="$exe" exec "$ROOT/scripts/proton-run.sh" run "$title" --execute "$@"
