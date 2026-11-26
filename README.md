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

## Hardware and frame rates

All figures are frames per second rendered by the title, in Series S mode,
with the launcher's defaults. Frame generation (FSR 3, DLSS) is not counted:
builds that announce 35 to 45 fps on Windows show interpolated frames, and
their rendered rate is close to the figures below.

### Measured under Linux

| Graphics card | Processor | RAM | Result |
|---|---|---|---|
| AMD RX 6950 XT, 16 GB (RDNA 2), Mesa 26.2.6 | Ryzen 9 7900X, 24 threads | 32 GB DDR5 | 19 to 21 fps median while moving (prologue, boat), 28 to 30 in cutscenes, no crash over a night of runs |
| NVIDIA RTX 5060 Ti, 16 GB, driver 620.70.6, Resizable BAR on | Core i5-14600KF, 6 P-cores and 8 E-cores, 20 threads | DDR5 | about 13 fps median in the prison |
| Same, Resizable BAR off | same | same | 1.5 to 3.4 fps |

For comparison, the fastest Windows builds measure 21 fps median on an RTX
4090 with a Ryzen 9 9950X3D (Vice-Tay, 30-minute playtest).

### What sets the frame rate

The title's memory is copied to the card every frame, and the translation
of its command lists runs on the processor. The processor's speed per core
matters more than the graphics card, then the card's memory and the system
memory.

| Part | Recommended | Works | Not enough or not tested |
|---|---|---|---|
| Processor | 16 logical threads or more, fast cores (Ryzen 7000/9000, Core 13th/14th generation) | 12 threads | fewer than 12 threads: not tested |
| Intel P-cores and E-cores | run as is | pinning to P-cores (`taskset`) gave no proven gain | |
| RAM | 64 GB | 32 GB: the title swaps in busy scenes and the rate drops for a few seconds (zram helps) | 16 GB: not tested, the title alone keeps 24 to 37 GB |
| AMD card | RDNA 2 or RDNA 3 with 16 GB (RX 6800 and up, RX 7800 XT and up) | 12 GB: not tested, try `VICTORY_PROFILE=nvidia` (less card memory) | RDNA 1 and older: no mesh shaders in RADV. RDNA 4: not tested |
| NVIDIA card | RTX 40 or 50 series with 12 GB or more | RTX 30 series: not tested under Linux | 8 GB cards: not tested |
| Resizable BAR (AMD Smart Access Memory) | on | | off: copies crawl, about 2 fps on NVIDIA |

### Expected rates (estimates, not measured)

| Setup | Expected |
|---|---|
| RX 6800/6900/7900 or RTX 4070 Ti/4080/5070 Ti and up, 16+ threads, 32 GB or more | 17 to 22 fps while moving |
| RTX 4060 Ti/5060 Ti 16 GB or RX 7800 XT, 12 to 20 threads, 32 GB | 12 to 16 fps |
| 8 GB cards, or 16 GB of RAM | below 10 fps, or not playable |

### Before asking

- The first entry into the world builds the shaders: a few minutes at 0 to 1
  fps, once. Later launches load them from the cache.
- Models and textures stay in low detail for about ten seconds after
  loading, then sharpen: the title streams them in.
- Turn on Resizable BAR ("Above 4G Decoding" and "Re-Size BAR Support" in
  the firmware settings). On NVIDIA cards `nvidia-smi -q | grep -A3 -i bar1`
  shows its size: about 256 MiB means it is off.
- Update with `git checkout main && git pull`: a checkout of a tag
  (`v0.1.2`) does not update.
- Keep the log when asking for help:
  `./run-amd.sh /path/to/game 2>&1 | tee victory.log` (or `run-nvidia.sh`).
- `MANGOHUD=1` in front of the launcher shows the frame rate, when MangoHud
  is installed.
- Known defect: now and then a character's face or clothes show blocks of
  another texture, mostly right after loading.
## Keyboard fallback

With no gamepad connected the keyboard stands in as one pad. The default
keys (W A S D and I J K L for the sticks, Enter Backspace X Y on the face,
Q E Z C on the shoulders and triggers, F H on the stick clicks, arrows on
the d-pad, Esc and Tab on Menu and View) live in `keybinds.conf`. Copy
`keybinds.example.conf` next to the executable, or set `VICTORY_KEYBINDS`
to your own file, and edit it while the game runs: changes are picked up
within a second, and a bad line only warns. A plugged-in gamepad always
wins over the stand-in.

## Status (version 0.1.2)

Tested on CachyOS with an AMD RX 6950 XT (RADV, Mesa 26.2.6), 32 GB of
RAM and Proton Experimental `experimental-11.0-20261112`.

- victory-corgi plays the prologue and the first boat ride without a crash
  or a hang, at a median of 18.5 frames a second in game (a tenth of the
  time under 13.2), in Series S mode. Faces, their animation, clothes,
  trees, light and textures are right.
- On AMD cards `run.sh` keeps vkd3d-proton off its descriptor heap
  (`VKD3D_CONFIG=no_descriptor_heap`): on RADV that path gives the title's
  facial animation two to three times too strong expressions, some
  clothes come out black and trees flicker. `VICTORY_DESCRIPTOR_HEAP=1` keeps the heap.
- On NVIDIA cards (an RTX 5060 Ti under Linux) the picture is right with
  victory-corgi's NVIDIA settings, which `run.sh` now picks there. The
  first entry into the world compiles shaders for a few minutes. Copies
  are slow without Resizable BAR: turn on "Above 4G Decoding" and
  "Re-Size BAR Support" in the firmware settings.
- With 32 GB of RAM the title swaps in its busiest scenes, and the frame
  rate drops for a few seconds. 64 GB are recommended by the builds'
  authors.
- Menus and videos run at 60 frames a second.
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
  its dxil-spirv fix (from this repository's `vkd3d-proton-master` release
  when the GitHub CLI is not signed in).
- `scripts/amdvlk.sh` and `VICTORY_DRIVER=amdvlk`, which run the title on
  AMD's own Vulkan driver, without installing it.
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
