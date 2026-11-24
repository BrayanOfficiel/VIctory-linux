#!/bin/sh
# Runs a Windows program, VIctory or one of its test binaries, under the
# system's Wine with VKD3D-Proton for Direct3D 12 and DXVK's DXGI taken from
# a Proton build (proton-run.sh uses Proton's own Wine). Also a cargo runner
# (CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER). See docs/linux-proton.md.
#
# VICTORY_WINEPREFIX  the prefix, made on first use
#                     (default: $XDG_DATA_HOME/victory/wine)
# VICTORY_PROTON      the Proton build whose VKD3D-Proton and DXVK are used
#                     (default: the newest one Steam has)
set -eu

data=${XDG_DATA_HOME:-$HOME/.local/share}
prefix=${VICTORY_WINEPREFIX:-$data/victory/wine}

# Proton builds that ship both, newest last by their version stamp.
newest_proton() {
    for dir in "$data"/Steam/compatibilitytools.d/* \
        /usr/share/steam/compatibilitytools.d/* \
        "$data"/Steam/steamapps/common/Proton*; do
        [ -f "$dir/files/lib/wine/vkd3d-proton/x86_64-windows/d3d12core.dll" ] || continue
        [ -f "$dir/files/lib/wine/dxvk/x86_64-windows/dxgi.dll" ] || continue
        printf '%s %s\n' "$(cut -d' ' -f1 "$dir/version" 2>/dev/null || echo 0)" "$dir"
    done | sort -n | tail -n 1 | cut -d' ' -f2-
}

proton=${VICTORY_PROTON:-$(newest_proton)}
lib=$proton/files/lib/wine
if [ -z "$proton" ] || [ ! -f "$lib/vkd3d-proton/x86_64-windows/d3d12core.dll" ]; then
    echo "wine-run.sh: no Proton build with VKD3D-Proton and DXVK; set VICTORY_PROTON" >&2
    exit 1
fi

export WINEPREFIX="$prefix"
export WINEDEBUG="${WINEDEBUG:--all}"
# Wine Mono and Gecko are not needed, and would ask to be installed.
export WINEDLLOVERRIDES="d3d12,d3d12core,dxgi=n;mscoree,mshtml="

# Made without a display, so no window opens. Crashes then print a
# backtrace instead of opening a dialog. The mark comes last: a setup cut
# short runs again.
if [ ! -f "$prefix/.victory" ]; then
    mkdir -p "$prefix"
    env -u DISPLAY -u WAYLAND_DISPLAY wineboot -i
    env -u DISPLAY -u WAYLAND_DISPLAY wine reg add 'HKCU\Software\Wine\WineDbg' \
        /v ShowCrashDialog /t REG_DWORD /d 0 /f >/dev/null
    wineserver -w
    touch "$prefix/.victory"
fi

# Copied again when the Proton build changes.
system32=$prefix/drive_c/windows/system32
for dll in vkd3d-proton/x86_64-windows/d3d12.dll vkd3d-proton/x86_64-windows/d3d12core.dll \
    dxvk/x86_64-windows/dxgi.dll; do
    cmp -s "$lib/$dll" "$system32/${dll##*/}" || install -m 644 "$lib/$dll" "$system32/"
done

# VKD3D-Proton keeps its cache in the working directory otherwise.
export VKD3D_SHADER_CACHE_PATH="${VKD3D_SHADER_CACHE_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/victory/vkd3d-proton}"
mkdir -p "$VKD3D_SHADER_CACHE_PATH"

exec wine "$@"
