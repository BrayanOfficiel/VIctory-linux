#!/usr/bin/env bash
# Makes a Proton whose Wine server finds a process's memory views in a tree
# instead of walking the list of all of them.
#
# A title maps and unmaps thousands of memory views a frame, and Wine's
# server checks each new view against every view of the process and walks
# the same list to find one. With the views in a tree ordered by address
# (scripts/wineserver-view-tree.patch, from Marvisak/VIctory issue #340), a
# world frame took 556 ms instead of 2,600 to 2,960 (RX 6950 XT, Proton
# Experimental 11.0-20261112; docs/linux-proton.md).
#
#   scripts/proton-viewtree.sh [output folder]
#
# Only the server is built, from the Wine source of the installed Proton
# Experimental (the commit its release tag's `wine` submodule names). The
# output folder (default ~/.local/share/victory/proton-viewtree, which
# scripts/proton-run.sh then uses on its own) holds hard links to every
# other file of that Proton, or a copy where hard links cannot be made.
# Run it again after Steam updates Proton Experimental.
#
# Needs git, curl, autoconf, flex, bison, perl, python3 and a C compiler.
# The Wine source and build stay in ~/.cache/victory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/victory"
OUT="${1:-$DATA/proton-viewtree}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/victory"
MARK=.victory-viewtree

STOCK="${PROTON_SOURCE:-}"
if [[ -z "$STOCK" ]]; then
    for d in "$HOME/.steam/steam/steamapps/common/Proton - Experimental" \
             "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental" \
             "$HOME/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/common/Proton - Experimental"; do
        if [[ -x "$d/files/bin/wine" ]]; then STOCK="$d"; break; fi
    done
fi
if [[ -z "$STOCK" || ! -f "$STOCK/version" ]]; then
    echo "Proton Experimental not found: install it in Steam or set PROTON_SOURCE" >&2
    exit 1
fi
STOCK="$(realpath "$STOCK")"

# "1794497090 experimental-11.0-20261112-x86_64": the release tag is the
# second field without its architecture.
version=$(awk '{print $2}' "$STOCK/version")
tag=${version%-x86_64}
commit=$(curl -fsSL "https://api.github.com/repos/ValveSoftware/Proton/contents/wine?ref=$tag" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["sha"])')
echo "Proton $tag: Wine $commit"

src="$CACHE/wine-$commit"
if [[ ! -f "$src/.prepared" ]]; then
    rm -rf "${src:?}"
    mkdir -p "$src"
    git -C "$src" init -q
    git -C "$src" fetch -q --depth 1 https://github.com/ValveSoftware/wine "$commit"
    git -C "$src" checkout -q FETCH_HEAD
    git -C "$src" apply "$ROOT/scripts/wineserver-view-tree.patch"
    # Files Proton's build generates before configure: the server protocol
    # (Proton's ntdll speaks the regenerated one), the syscall tables and
    # winevulkan's headers, which the makefile generator reads.
    (cd "$src" && ./tools/make_requests && ./tools/make_specfiles) >/dev/null
    (cd "$src/dlls/winevulkan" && python3 make_vulkan -x vk.xml -X video.xml) >/dev/null
    (cd "$src" && autoreconf -fi) >/dev/null 2>&1
    touch "$src/.prepared"
fi

build="$src/build"
if [[ ! -f "$build/Makefile" ]]; then
    mkdir -p "$build"
    (cd "$build" && ../configure --enable-win64 --disable-tests --without-x --without-wayland \
        --without-gstreamer --without-cups --without-sane --without-pcap --without-capi \
        --without-v4l2 --without-gphoto --without-krb5 --without-netapi --without-opencl \
        --without-pulse --without-alsa --without-oss --without-usb --without-sdl --without-unwind \
        --without-dbus --without-gnutls --without-freetype --without-fontconfig --without-vulkan \
        --without-osmesa CFLAGS="-O2" > configure.log 2>&1) ||
        { echo "configure failed: $build/configure.log" >&2; exit 1; }
fi
make -C "$build" -j"$(nproc)" server/wineserver > "$build/make.log" 2>&1 ||
    { echo "the server's build failed: $build/make.log" >&2; exit 1; }

# The output folder is only ever replaced when it is one this script made.
if [[ -e "$OUT" ]]; then
    if [[ ! -f "$OUT/$MARK" ]]; then
        echo "$OUT exists and was not made by this script: give another folder" >&2
        exit 1
    fi
    rm -rf "${OUT:?}"
fi
mkdir -p "$(dirname "$OUT")"
if ! cp -al "$STOCK" "$OUT" 2>/dev/null; then
    rm -rf "${OUT:?}"
    echo "hard links are not possible there: copying Proton (about 1.5 GB)" >&2
    cp -a "$STOCK" "$OUT"
fi
# A hard link shares its file with Steam's Proton: it is removed, never
# written through.
rm -f "${OUT:?}/files/bin/wineserver"
cp "$build/server/wineserver" "$OUT/files/bin/wineserver"
chmod 755 "$OUT/files/bin/wineserver"
echo "$version $commit" > "$OUT/$MARK"

# Check that this Proton's Wine starts this server, when no Wine runs in
# VIctory's prefix (proton-run.sh's default) and the prefix exists.
prefix="${PREFIX:-$DATA/proton}/pfx"
if [[ -f "$prefix/system.reg" ]] && ! pgrep -x wineserver >/dev/null; then
    env -u DISPLAY -u WAYLAND_DISPLAY WINEPREFIX="$prefix" WINEDEBUG=-all \
        "$OUT/files/bin/wine" cmd /c exit >/dev/null 2>&1 &
    server=""
    for _ in $(seq 40); do
        sleep 0.25
        pid=$(pgrep -x wineserver | head -1) || true
        if [[ -n "$pid" ]]; then server=$(readlink "/proc/$pid/exe"); break; fi
    done
    wait || true
    WINEPREFIX="$prefix" "$OUT/files/bin/wineserver" -k 2>/dev/null || true
    if [[ "$server" != "$(realpath "$OUT/files/bin/wineserver")" ]]; then
        echo "check failed: Wine started ${server:-no server} instead of $OUT/files/bin/wineserver" >&2
        exit 1
    fi
    echo "checked: this Proton's Wine starts the new server"
fi
echo "made $OUT (scripts/proton-run.sh uses it while it matches Proton $tag)"
