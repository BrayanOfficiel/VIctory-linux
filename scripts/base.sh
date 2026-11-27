#!/usr/bin/env bash
# Builds a VIctory base other than this checkout and prints the path of its
# release victory.exe, for run.sh (VICTORY_BUILD) and scripts/proton-run.sh
# (VICTORY_EXE):
#
#   scripts/base.sh klbf-lab        # PastiiJay/klbf-lab: AMD cards
#   scripts/base.sh victory-fork    # fxceless/victory-fork: NVIDIA cards
#   scripts/base.sh victory-7900xtx # avatarmanz/VIctory-7900XTX: AMD cards
#   scripts/base.sh victory-corgi   # corgansm/victory-corgi: NVIDIA cards
#   scripts/base.sh belobug         # Belobug/VIctory-Belobug-AMD: AMD cards
#   scripts/base.sh victory-drae    # Draesia/victory-drae: victory-corgi and more
#
# Each base is fetched at a fixed commit into ~/.cache/victory/bases,
# patched with scripts/bases/<name>/*.patch (fixes for Proton) and built
# with cargo-xwin. These bases compile their own HLSL with methods Wine's
# compiler lacks (RWByteAddressBuffer), so Microsoft's d3dcompiler_47.dll is
# put next to the exe: from D3DCOMPILER_47 when set, else
# ~/.local/share/victory/d3dcompiler_47.dll (copied from a Windows install's
# System32).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
name="${1:?usage: scripts/base.sh klbf-lab|victory-fork|victory-7900xtx|victory-corgi|belobug|victory-drae}"
case "$name" in
    klbf-lab) repo=https://github.com/PastiiJay/klbf-lab commit=3c2dbec66faafe6701d86090d5e7e53957f5c88c ;;
    victory-fork) repo=https://github.com/fxceless/victory-fork commit=085ee7c4c3d1dfaed41d683fa9f465a6f9dac8c3 ;;
    victory-7900xtx) repo=https://github.com/avatarmanz/VIctory-7900XTX commit=a9400a6d62ccc8309dab9a5f38a2eb730ce176aa ;;
    victory-corgi) repo=https://github.com/corgansm/victory-corgi commit=8b6671cc29f491cfb717a796808c47706c46aa9e ;;
    belobug) repo=https://github.com/Belobug/VIctory-Belobug-AMD commit=cd8dfc06ace7ccb91a19431e74bc2d0de2a10145 ;;
    victory-drae) repo=https://github.com/Draesia/victory-drae commit=10a5bbafca2446f4235657d3fcc8fa047286cf5d ;;
    *) echo "base.sh: unknown base $name (klbf-lab, victory-fork, victory-7900xtx, victory-corgi, belobug, victory-drae)" >&2; exit 2 ;;
esac

src="${XDG_CACHE_HOME:-$HOME/.cache}/victory/bases/$name-${commit:0:12}"
shopt -s nullglob
patches=("$ROOT/scripts/bases/$name"/*.patch)
# The patches applied, by content: a changed or new one is applied again
# over a clean checkout (the build directory stays).
want="$(cat /dev/null "${patches[@]}" | sha256sum | cut -d' ' -f1)"
if [[ "$(cat "$src/.prepared" 2>/dev/null)" != "$want" ]]; then
    if [[ ! -d "$src/.git" ]]; then
        echo "base.sh: fetching $name at ${commit:0:12}" >&2
        rm -rf "${src:?}"
        mkdir -p "$src"
        git -C "$src" init -q
        # GitHub first, then git.gtahub.st's mirror of it (forks get taken
        # down: VIctory-7900XTX and VIctory-Belobug-AMD on 2026-11-27).
        mirror="https://git.gtahub.st/github/$(basename "$(dirname "$repo")")--$(basename "$repo")"
        if ! GIT_TERMINAL_PROMPT=0 git -C "$src" fetch -q --depth 1 "$repo" "$commit"; then
            echo "base.sh: $repo is not there, trying its mirror $mirror" >&2
            GIT_TERMINAL_PROMPT=0 git -C "$src" fetch -q --depth 1 "$mirror" "$commit"
        fi
        git -C "$src" checkout -q FETCH_HEAD
    else
        echo "base.sh: applying $name's patches again" >&2
        git -C "$src" reset -q --hard
        git -C "$src" clean -fdq -e /target -e /.prepared
    fi
    for patch in "${patches[@]}"; do
        git -C "$src" apply "$patch"
    done
    echo "$want" >"$src/.prepared"
    rm -f "$src/target/x86_64-pc-windows-msvc/release/victory.exe"
fi

exe="$src/target/x86_64-pc-windows-msvc/release/victory.exe"
if [[ ! -f "$exe" ]]; then
    echo "base.sh: building $name (release), several minutes the first time" >&2
    (cd "$src" && XWIN_ACCEPT_LICENSE=1 CARGO_TARGET_DIR="$src/target" \
        cargo xwin build --release -p victory --target x86_64-pc-windows-msvc) >&2
fi

dll="${D3DCOMPILER_47:-${XDG_DATA_HOME:-$HOME/.local/share}/victory/d3dcompiler_47.dll}"
if [[ ! -f "$dll" ]]; then
    cat >&2 <<EOF
base.sh: $name needs Microsoft's d3dcompiler_47.dll, not found at $dll.
Copy it from a Windows install (C:\\Windows\\System32\\d3dcompiler_47.dll) to
that path, or set D3DCOMPILER_47 to a copy of it.
EOF
    exit 1
fi
cp -f "$dll" "$(dirname "$exe")/d3dcompiler_47.dll"
echo "$exe"
