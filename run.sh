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

# Series S mode unless --console is given: the title renders at 1280x720
# and upscales with AMD FidelityFX, here the PC build of AMD's SDK (the
# console's draws white under Proton). In the prologue's cell a frame took
# 220 to 270 ms instead of 290 to 380 in Series X mode (RX 6950 XT).
console=()
if [[ -z "${VICTORY_FIDELITYFX_DIR:-}" ]]; then
    ffx="${XDG_DATA_HOME:-$HOME/.local/share}/victory/fidelityfx"
    sdk="https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/v2.4.0/Kits/FidelityFX/signedbin"
    for dll in amd_fidelityfx_loader_dx12.dll amd_fidelityfx_upscaler_dx12.dll; do
        if [[ ! -s "$ffx/$dll" ]]; then
            mkdir -p "$ffx"
            echo "run.sh: downloading $dll (AMD FidelityFX SDK 2.4.0, MIT licence)" >&2
            curl -fL --retry 3 -o "$ffx/$dll.part" "$sdk/$dll" && mv "$ffx/$dll.part" "$ffx/$dll" ||
                rm -f "${ffx:?}/$dll.part"
        fi
    done
    if [[ -s "$ffx/amd_fidelityfx_loader_dx12.dll" && -s "$ffx/amd_fidelityfx_upscaler_dx12.dll" ]]; then
        export VICTORY_FIDELITYFX_DIR="Z:${ffx//\//\\}"
    fi
fi
if [[ -n "${VICTORY_FIDELITYFX_DIR:-}" && " $* " != *" --console "* ]]; then
    console=(--console series-s)
fi
VICTORY_EXE="$exe" exec "$ROOT/scripts/proton-run.sh" run "$title" --execute "${console[@]}" "$@"
