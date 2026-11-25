# VIctory for Linux

[VIctory](https://github.com/Marvisak/VIctory) runs Xbox Series titles on a
PC: it loads the title's executable, answers its system calls and
translates its GPU work to Direct3D 12. This fork runs VIctory on Linux,
under Proton's Wine, with vkd3d-proton (Direct3D 12 on Vulkan) and DXVK's
DXGI.

The upstream README is kept as [README.victory.md](README.victory.md).

## Quick start

Requirements:

- Proton Experimental, installed from Steam (Library, then Tools).
- A Vulkan driver with mesh shaders. RADV on RDNA 2 or later has them.
- `rustup` and [`cargo-xwin`](https://github.com/rust-cross/cargo-xwin).
- A copy of the game you own. This repository holds no game files.

```sh
rustup target add x86_64-pc-windows-msvc
cargo install --locked cargo-xwin
./run.sh /path/to/game
```

`run.sh` takes the folder holding the title's executable, or the executable
itself. The first run builds VIctory (cargo-xwin then downloads the MSVC
runtime and the Windows SDK, and accepts their licence). Wine runs in a
prefix of its own, `~/.local/share/victory/proton`, made on first use.

## Status

Tested on CachyOS with an AMD RX 6950 XT (RADV, Mesa 26.2.6) and Proton
Experimental `experimental-11.0-20261112`.

- The title boots, runs its menus at its own 30 frames a second and loads
  the opening scene.
- In the world, a frame takes about 3 seconds. Keeping the title's memory
  and the GPU in step costs much more under Wine than on Windows, and the
  world itself is still mostly unlit, as upstream.
- After about 10 minutes of play the title stops itself when one of its
  object pools fills up. This also happens on Windows (upstream issue #698).
- A PlayStation pad (DualSense) works as an XInput pad, with the Xbox
  buttons' names in the title.

## What this fork adds

- `run.sh`, `scripts/proton-run.sh` and `scripts/wine-run.sh`, which set up
  Proton or the system's Wine with vkd3d-proton and DXVK.
- Fixes for Wine and vkd3d-proton: VIctory's own shaders build with Wine's
  HLSL compiler, an empty pipeline library is asked for with a null blob,
  each translated program returns from one block (dxil-spirv cannot
  structure a loop left by both a break and a return), network functions
  Wine lacks fail cleanly, and the write tracking makes fewer protection
  changes, which are slow under Wine.
- Upstream pull requests taken ahead of upstream: #454 (an opt-in hook for
  the title's watchdog, on by default in `run.sh`), #1849, #1084, #416,
  #1014 and #1737.
- The test suite runs under Wine.

[docs/linux-proton.md](docs/linux-proton.md) has the details: requirements,
building, running, tests and the known differences with Windows.

## Licence

GPL-3.0, as upstream: see [LICENSE](LICENSE).
