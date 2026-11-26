#!/usr/bin/env bash
# Runs a title with VIctory on Linux, under Proton (see docs/linux-proton.md).
#
#   ./run.sh <game folder, or the title's exe> [more `victory run` options]
#
# The VIctory build depends on the graphics card, unless VICTORY_BUILD names
# one: corgansm's victory-corgi on AMD and NVIDIA cards (built by
# scripts/base.sh), this
# checkout's build ("victory") on others. This checkout's release build is
# made first if it is missing (cargo-xwin). The title's watchdog is off
# unless VICTORY_NO_WATCHDOG says otherwise: a world load under Wine can
# outlast it.
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

# The card's maker, from the kernel's view of the cards (an NVIDIA card wins
# over an AMD integrated GPU).
gpu_vendor() {
    local file vendors=""
    for file in /sys/class/drm/card*/device/vendor; do
        [[ -r "$file" ]] && vendors+=" $(<"$file")"
    done
    case "$vendors" in
        *0x10de*) echo nvidia ;;
        *0x1002*) echo amd ;;
        *) echo other ;;
    esac
}
build="${VICTORY_BUILD:-}"
if [[ -z "$build" ]]; then
    case "$(gpu_vendor)" in
        amd) build=victory-corgi ;;
        nvidia) build=victory-corgi ;;
        *) build=victory ;;
    esac
fi
echo "run.sh: VIctory build: $build (VICTORY_BUILD=victory, victory-7900xtx, victory-corgi, victory-drae, belobug, nvidia-alt, klbf-lab or victory-fork)" >&2

# A variable's value unless it is set already.
default() {
    [[ -n "${!1+x}" ]] || export "$1=$2"
}
case "$build" in
    victory)
        target="${CARGO_TARGET_DIR:-$ROOT/target}"
        exe="$target/x86_64-pc-windows-msvc/release/victory.exe"
        if [[ ! -f "$exe" ]]; then
            echo "run.sh: building VIctory (release) first" >&2
            (cd "$ROOT" && XWIN_ACCEPT_LICENSE=1 cargo xwin build --release -p victory --target x86_64-pc-windows-msvc)
        fi
        ;;
    klbf-lab)
        exe="$("$ROOT/scripts/base.sh" klbf-lab)"
        # klbf-lab's settings for AMD cards (its docs/GUIDE.md), with late
        # waits off: they lose the device on RADV. It splits its own ballots
        # for 64-lane waves, so RADV's waves stay as they are.
        default VICTORY_SHADER_OPT 0
        default VICTORY_SKIP_PIPELINES 39f0e9aeb156a61c
        default VICTORY_LATE_WAIT 0
        default VICTORY_WIDE_BACK 0
        default VICTORY_PIPELINE_WAIT_MS 24
        default VICTORY_RELAY_COPY_QUEUE 0
        default VICTORY_CARD_BUFFERS_MIN_MB 1
        default VICTORY_CARD_BUFFERS_MB 1024
        default VICTORY_RADV_WAVE32 0
        ;;
    victory-7900xtx | nvidia-alt | belobug)
        # Belobug/VIctory-Belobug-AMD: VIctory-7900XTX's newer renderer
        # with RX 9070 XT fixes and textures sent ahead of each submission.
        exe="$("$ROOT/scripts/base.sh" "${build/nvidia-alt/victory-7900xtx}")"
        # Its own settings (scripts/play.ps1 there, without -Safe).
        for setting in TEXTURE_NO_WAIT=1 RELAY=2 WIDE_BACK=1 CARD_REHASH_RUNS=1 JOIN_COPIES=1 \
            INDIRECT_WINDOW=1 RELAY_COPY=1 CARD_STEPS=2 INDIRECT_BATCH=2 MAP_THREADS=1 \
            TITLE_PRIORITIES=0 CARD_AWAKE=1 SHOW_AFTER=1 AMBIENT=0.8 D3D12_DRED=light \
            THIN=1 JOIN_PARTS=8 UPLOAD_AHEAD=1; do
            default "VICTORY_${setting%%=*}" "${setting#*=}"
        done
        if [[ "$build" == nvidia-alt ]]; then
            # The same build on NVIDIA cards, with trustno1-coder's
            # VIctory-NVIDIA settings: more dynamic slots on a view heap
            # capped at 1,000,000 views (patch 06), and card buffers.
            for setting in DYNAMIC_SLOTS=524288 CARD_BUFFERS_MIN_MB=1 CARD_BUFFERS_MB=1536; do
                default "VICTORY_${setting%%=*}" "${setting#*=}"
            done
        fi
        ;;
    victory-corgi | victory-drae)
        # victory-drae: Draesia's victory-corgi with 4 KiB parts fetched
        # back (VICTORY_FETCH_PARTS), one pipeline-wait budget for all
        # threads, a larger buffer-lookup cache and Switch Pro pads.
        exe="$("$ROOT/scripts/base.sh" "$build")"
        # Its own settings, by card: scripts/play-nvidia.ps1 there on NVIDIA
        # cards (measured on an RTX 5070: 20-22 fps, no device loss), its
        # play-highram.ps1 elsewhere (every title buffer copied to the card,
        # results fetched in flight checked: more card and host memory).
        # VICTORY_PROFILE=nvidia or highram picks one.
        profile="${VICTORY_PROFILE:-$([[ "$(gpu_vendor)" == nvidia ]] && echo nvidia || echo highram)}"
        common="TEXTURE_NO_WAIT=1 RELAY=2 WIDE_BACK=1 CARD_REHASH_RUNS=1 JOIN_COPIES=1
            INDIRECT_WINDOW=1 RELAY_COPY=1 CARD_STEPS=2 INDIRECT_BATCH=2 MAP_THREADS=1
            TITLE_PRIORITIES=0 CARD_AWAKE=1 SHOW_AFTER=1 AMBIENT=0.8 D3D12_DRED=light
            SKIP_PIPELINES=none JOIN_PARTS=8 UPLOAD_AHEAD=1 PIPELINE_WAIT_MS=10000
            DYNAMIC_SLOTS=524288 OWN_UPSCALER=1 BVH_MISS=1 CARD_BUFFERS_MIN_MB=1
            CARD_BUFFERS_MB=1536 COMPOSE=1"
        case "$profile" in
            nvidia) own="THIN=1 RENDER_SCALE=0.5" ;;
            highram) own="THIN=0 F16_NEAREST=1 CARD_ALL=1 FETCH_CHECK=1
                PAIRED_ONLY=b5b838548eaa4050638308fb2c805641,2431bbe7dc154ad759d20bc954829c1c" ;;
            *) echo "run.sh: unknown VICTORY_PROFILE $profile (nvidia or highram)" >&2; exit 2 ;;
        esac
        echo "run.sh: victory-corgi settings: $profile" >&2
        for setting in $common $own; do
            default "VICTORY_${setting%%=*}" "${setting#*=}"
        done
        ;;
    victory-fork)
        exe="$("$ROOT/scripts/base.sh" victory-fork)"
        ;;
    *)
        echo "run.sh: unknown VICTORY_BUILD $build" >&2
        exit 2
        ;;
esac
if [[ "$build" != victory ]]; then
    # Its own HLSL needs Microsoft's compiler, put next to the exe.
    export WINEDLLOVERRIDES="d3dcompiler_47=n,b;${WINEDLLOVERRIDES:-}"
fi
export VICTORY_NO_WATCHDOG="${VICTORY_NO_WATCHDOG-1}"
# 60 frames a second instead of the title's 30, unless VICTORY_FRAME_RATE
# says otherwise (0: no pacing). This checkout reads VICTORY_FRAME_RATE;
# VIctory-7900XTX takes an interval and gives the title the same rate, so
# its game time follows.
export VICTORY_FRAME_RATE="${VICTORY_FRAME_RATE-60}"
if [[ "$build" == victory-7900xtx || "$build" == nvidia-alt || "$build" == victory-corgi || "$build" == victory-drae || "$build" == belobug ]]; then
    if [[ "$VICTORY_FRAME_RATE" == 0 ]]; then
        default VICTORY_FRAME_INTERVAL_MS 0
    else
        default VICTORY_FRAME_INTERVAL_MS "$(awk -v r="$VICTORY_FRAME_RATE" 'BEGIN { printf "%.3f", 1000 / r }')"
    fi
fi
# The title's BVH walks need vkd3d-proton master's dxil-spirv (Proton's
# recurses without end on them, which stops pipelines being made).
if [[ -z "${VICTORY_VKD3D_DIR+x}" ]] && ! "$ROOT/scripts/vkd3d-proton-master.sh" >/dev/null; then
    echo "run.sh: vkd3d-proton master is missing (no network?): pipelines may stop being made" >&2
fi

# On RADV, vkd3d-proton master reads descriptors through
# VK_EXT_descriptor_heap; the title's face network then gives expressions
# two to three times too strong, some clothes come out black and trees
# flicker. Through VK_EXT_descriptor_buffer, the way it takes on AMDVLK,
# they are right (RX 6950 XT, Mesa 26.2.6). VICTORY_DESCRIPTOR_HEAP=1 keeps
# the heap.
if [[ "$(gpu_vendor)" == amd && "${VICTORY_DRIVER:-}" != amdvlk && "${VICTORY_DESCRIPTOR_HEAP:-0}" != 1 ]]; then
    case ",${VKD3D_CONFIG:-}," in
        *,no_descriptor_heap,*) ;;
        *) export VKD3D_CONFIG="${VKD3D_CONFIG:+$VKD3D_CONFIG,}no_descriptor_heap" ;;
    esac
fi

# VICTORY_DRIVER=amdvlk: AMD's own Vulkan driver instead of RADV
# (scripts/amdvlk.sh), the one the title's face animation is right on.
if [[ "${VICTORY_DRIVER:-}" == amdvlk ]]; then
    if icd="$("$ROOT/scripts/amdvlk.sh")"; then
        export VK_DRIVER_FILES="$icd"
        echo "run.sh: Vulkan driver: AMDVLK" >&2
    else
        echo "run.sh: AMDVLK could not be fetched: staying on the system's driver" >&2
    fi
fi

# Series S mode unless --console is given, for the builds that hand the
# title's upscaling to AMD FidelityFX on the host: the title renders at
# 1280x720 and upscales with the PC build of AMD's SDK (the console's draws
# white under Proton). In the prologue's cell a frame took 220 to 270 ms
# instead of 290 to 380 in Series X mode (this checkout, RX 6950 XT).
console=()
if [[ "$build" == victory || "$build" == klbf-lab || "$build" == victory-corgi || "$build" == victory-drae || "$build" == belobug ]]; then
    ffx="${XDG_DATA_HOME:-$HOME/.local/share}/victory/fidelityfx"
    sdk="https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/v2.4.0/Kits/FidelityFX/signedbin"
    # The SDK 2.4.0 files' SHA-256: a download is kept only if it matches.
    declare -A sums=(
        [amd_fidelityfx_loader_dx12.dll]=e2191d3c0828be45eb8affd4e3ec0378f2293adc345b772a7170edcf3b021ecb
        [amd_fidelityfx_upscaler_dx12.dll]=aad4fccccb29084a655f9a4f9f613bd22c8c03fb4a0f8840148cc6543b4ccace
    )
    matches() {
        echo "${sums[$1]}  $2" | sha256sum --quiet -c - >/dev/null 2>&1
    }
    ffx_ok=1
    for dll in "${!sums[@]}"; do
        if [[ ! -s "$ffx/$dll" ]]; then
            mkdir -p "$ffx"
            echo "run.sh: downloading $dll (AMD FidelityFX SDK 2.4.0, MIT licence)" >&2
            if curl -fL --retry 3 -o "$ffx/$dll.part" "$sdk/$dll" && matches "$dll" "$ffx/$dll.part"; then
                mv "$ffx/$dll.part" "$ffx/$dll"
            else
                rm -f "${ffx:?}/$dll.part"
            fi
        fi
        if ! matches "$dll" "$ffx/$dll"; then
            echo "run.sh: $ffx/$dll is missing or not the SDK 2.4.0 file: Series X mode" >&2
            ffx_ok=0
        fi
    done
    if (( ffx_ok )); then
        # This checkout reads the first name, klbf-lab the second.
        default VICTORY_FIDELITYFX_DIR "Z:${ffx//\//\\}"
        default VICTORY_FFX_DIR "$VICTORY_FIDELITYFX_DIR"
        if [[ " $* " != *" --console "* ]]; then
            console=(--console series-s)
        fi
    fi
fi
# VICTORY_DIAG=1: the same build's diagnostics exe, when it was built
# (cargo xwin build --profile diag --features diagnostics in its folder).
if [[ "${VICTORY_DIAG:-0}" == 1 ]]; then
    diag="${exe/\/release\//\/diag\/}"
    if [[ -f "$diag" ]]; then exe="$diag"; else echo "run.sh: no diagnostics build at $diag" >&2; fi
fi
# The stand-in pad's keys: a `keybinds.conf` in this folder (copy
# `keybinds.example.conf`) is passed to the game when VICTORY_KEYBINDS
# says nothing. Edit it while the title runs; changes land within a second.
if [[ -z "${VICTORY_KEYBINDS:-}" && -f "$ROOT/keybinds.conf" ]]; then
    export VICTORY_KEYBINDS="$ROOT/keybinds.conf"
fi
VICTORY_EXE="$exe" exec "$ROOT/scripts/proton-run.sh" run "$title" --execute "${console[@]}" "$@"
