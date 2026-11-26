#!/usr/bin/env bash
# Downloads AMD's own open-source Vulkan driver, AMDVLK (its last release,
# v-2025.Q2.1), into ~/.local/share/victory/amdvlk, without installing it,
# and prints the driver manifest to give the Vulkan loader
# (VK_DRIVER_FILES): only the programs started with it use AMDVLK.
#
# The title's face network (its compute_graph_ops) gives expressions two
# to three times too strong on RADV (Mesa 26.2.6, RX 6950 XT); on AMDVLK,
# with the same vkd3d-proton and Proton, they are right.
set -euo pipefail
version=2025.Q2.1
url="https://github.com/GPUOpen-Drivers/AMDVLK/releases/download/v-$version/amdvlk_${version}_amd64.deb"
dir="${XDG_DATA_HOME:-$HOME/.local/share}/victory/amdvlk"
so="$dir/root/usr/lib/x86_64-linux-gnu/amdvlk64.so"

if [[ "$(cat "$dir/.version" 2>/dev/null)" != "$version" || ! -f "$so" ]]; then
    echo "amdvlk.sh: downloading AMDVLK $version" >&2
    tmp=$(mktemp -d)
    trap 'rm -rf "${tmp:?}"' EXIT
    curl -fsSL "$url" -o "$tmp/amdvlk.deb"
    (cd "$tmp" && bsdtar -xf amdvlk.deb && mkdir root && bsdtar -xf data.tar.* -C root)
    rm -rf "${dir:?}"
    mkdir -p "$dir"
    mv "$tmp/root" "$dir/root"
    echo "$version" >"$dir/.version"
fi
# The driver alone, without its "switchable graphics" layer.
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s","api_version":"1.4.313"}}\n' \
    "$so" >"$dir/amd_icd64.json"
echo "$dir/amd_icd64.json"
