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
- On AMD and NVIDIA cards, Microsoft's `d3dcompiler_47.dll`, copied from a
  Windows install's `System32` to `~/.local/share/victory/d3dcompiler_47.dll`
  (the builds `run.sh` picks for them need it, see below).
- A copy of the game you own. This repository holds no game files.

```sh
rustup target add x86_64-pc-windows-msvc
cargo install --locked cargo-xwin
scripts/proton-viewtree.sh   # once: a faster Wine server (docs/linux-proton.md)
./run.sh /path/to/game
```

By card, with the same arguments:

| Launcher | Build |
|---|---|
| `./run-amd.sh` | corgansm's victory-corgi |
| `./run-nvidia.sh` | corgansm's victory-corgi |
| `./run-nvidia-alt.sh` | avatarmanz's VIctory-7900XTX with VIctory-NVIDIA's settings |

`run.sh` takes the folder holding the title's executable, or the executable
itself. It picks the build from the graphics card (victory-corgi on AMD and
NVIDIA cards, this checkout's elsewhere), or the one `VICTORY_BUILD` names
(`victory-corgi`, `victory-7900xtx`, `nvidia-alt`, `victory-fork`,
`klbf-lab`, `victory`). The first run builds it (cargo-xwin then downloads
the MSVC runtime and the Windows SDK, and accepts their licence). Wine runs
in a prefix of its own, `~/.local/share/victory/proton`, made on first use.
Key presses can be scripted for unattended runs (`VICTORY_KEYS`, see
docs/linux-proton.md).

## Status (version 0.1.0)

Tested on CachyOS with an AMD RX 6950 XT (RADV, Mesa 26.2.6), 32 GB of
RAM and Proton Experimental `experimental-11.0-20261112`.

- victory-corgi plays the prologue: 8 minutes in the opening scene without
  a crash or a hang, at a median of 18.5 frames a second (a tenth of the
  time under 10, at most 27), in Series S mode. Faces, light and textures
  are right.
- Known defects, on Windows too: mouths do not move on AMD cards, and trees
  flicker or vanish in places.
- On NVIDIA cards victory-corgi has not been run under Linux. Its author
  measures 19 to 26 frames a second on Windows, with moving mouths.
- With 32 GB of RAM the title swaps in its busiest scenes, and the frame
  rate drops for a few seconds. 64 GB are recommended by the builds'
  authors.
- Menus and videos run at 60 frames a second with VIctory-7900XTX, at 30
  with victory-corgi.
- A PlayStation pad (DualSense) works as an XInput pad, with the Xbox
  buttons' names in the title.

## What this fork adds

- `run.sh`, `scripts/proton-run.sh` and `scripts/wine-run.sh`, which set up
  Proton or the system's Wine with vkd3d-proton and DXVK.
- `scripts/proton-viewtree.sh`, which builds Proton's Wine server with a
  process's memory views in a tree: world frames about five times faster.
- `scripts/base.sh`, which builds the community's best VIctory builds
  (victory-corgi, VIctory-7900XTX, fxceless's victory-fork) with fixes for
  Proton, and `run-amd.sh`, `run-nvidia.sh`, `run-nvidia-alt.sh`.
- `scripts/vkd3d-proton-master.sh`, which fetches vkd3d-proton master for
  its dxil-spirv fix.
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
- `VICTORY_FRAME_RATE`, which sets the rate the title's frames are paced
  at (60 by default in `run.sh`), or lifts that cap (`0`).
- In the crash report, the state of the title's object pools when one runs
  out (upstream issue #698).

[docs/linux-proton.md](docs/linux-proton.md) has the details: requirements,
building, running, tests and the known differences with Windows.

## Licence

GPL-3.0, as upstream: see [LICENSE](LICENSE).
