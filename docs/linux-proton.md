# Linux (Proton)

VIctory is a Windows program, and it also runs on Linux under Proton's Wine
with vkd3d-proton for Direct3D 12 and DXVK's DXGI.

Its test suite passes there (2026-11-25): CachyOS, Linux 7.3, AMD RX 6950 XT
(RADV, Mesa 26.2.6), Proton Experimental `experimental-11.0-20261112`. The
title itself was not run on this build.

## Requirements

- Steam's **Proton Experimental** (Steam → Library → Tools). Older Protons
  may not work: GE-Proton 11-11's vkd3d-proton turns some translated
  shaders into invalid SPIR-V, on which RADV crashes (`vkCreateGraphicsPipelines`,
  exit code 3).
- A Vulkan driver with mesh shaders (RADV on RDNA 2 or later has them).
- `rustup` and [`cargo-xwin`](https://github.com/rust-cross/cargo-xwin)
  to build the Windows target on Linux.

## Building

```sh
rustup target add x86_64-pc-windows-msvc
cargo install --locked cargo-xwin
# cargo-xwin downloads the MSVC CRT and Windows SDK; this accepts their licence.
export XWIN_ACCEPT_LICENSE=1
cargo xwin build --release -p victory --target x86_64-pc-windows-msvc
```

The diagnostics build likewise:
`cargo xwin build --profile diag -p victory --features diagnostics --target x86_64-pc-windows-msvc`.

Only the MSVC target runs titles. The mingw target (`x86_64-pc-windows-gnu`)
builds, but Rust keeps its per-thread state there outside the static TLS
block the loader restores around a title's thread notices, so the first
thread std starts with a title attached aborts the process.

## Running

`scripts/proton-run.sh` runs `victory.exe` with Proton's Wine, in a prefix of
its own (`~/.local/share/victory/proton`, made on first use), with
vkd3d-proton and DXVK. Linux paths work as arguments.

```sh
scripts/proton-run.sh config
scripts/proton-run.sh run /path/to/game/<the title's exe> --execute
```

`PROTON` selects another Proton folder, `PREFIX` another prefix and
`VICTORY_EXE` another exe (the diagnostics build, say). Saves, settings and
`crashes.log` live in the prefix's `%LOCALAPPDATA%\victory\data` unless
`victory.toml` or `VICTORY_DATA_DIR` says otherwise. Wine's crash dialog is
off in that prefix: a crash prints its backtrace in the terminal instead.

With an Xbox controller connected, the keyboard is not a pad (as on
Windows), so `VICTORY_KEYS` presses do not reach the title either.

The title's own watchdog ends the process when its main thread has not
advanced for about 30 seconds, which a world load under Wine can exceed.
`VICTORY_NO_WATCHDOG=1` turns it off on build 1.0.2.1: the loader patches
its two sites, each only if its bytes are the expected ones, and leaves
other builds alone. It hides a stall without fixing it, so a real deadlock
then waits instead of ending the process.

### Without Proton (system Wine)

A system Wine works too (reported with Wine 11.22 on RDNA2, RDNA3 and
RDNA 3.5). What Proton brings has to be added:

- **vkd3d-proton 3.2 or newer**: `d3d12.dll` and `d3d12core.dll` (Proton
  Experimental's `files/lib/wine/vkd3d-proton/x86_64-windows`). 3.1 turns
  some translated shaders into SPIR-V RADV cannot take.
- **DXVK's `dxgi.dll`**, and `WINEDLLOVERRIDES="d3d12,d3d12core,dxgi=n"`.
- No Microsoft `d3dcompiler_47`: Wine's built-in one compiles the two
  shaders VIctory makes at run time (the argument clamp and the depth
  converter).

`scripts/wine-run.sh` does this with the system's `wine`, in a prefix of its
own (`~/.local/share/victory/wine`, made on first use without a window,
`VICTORY_WINEPREFIX` for another) with Wine's crash dialog off. It takes
vkd3d-proton and DXVK from the newest Proton build Steam has. If that one
ships vkd3d-proton 3.1, `VICTORY_PROTON` names Proton Experimental's folder
instead. It is a cargo runner too.

## Tests

```sh
cargo xwin build --manifest-path tests/fixtures/hle-probe/Cargo.toml \
    --target x86_64-pc-windows-msvc --target-dir target/hle-probe
export VICTORY_HLE_PROBE=$PWD/target/hle-probe/x86_64-pc-windows-msvc/debug/hle_probe.dll
CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER=$PWD/scripts/proton-run.sh \
    cargo xwin test --workspace --target x86_64-pc-windows-msvc --exclude xtask
cargo test -p xtask
```

Wine cannot start the Linux programs two tests start. So
`loads_binds_and_calls_probe` takes its stand-in title built beforehand
(`VICTORY_HLE_PROBE`) instead of building it with `cargo`, and xtask's
tests, whose asset-policy check runs `git`, run natively.

With two GPUs, `DXVK_FILTER_DEVICE_NAME` and `VKD3D_FILTER_DEVICE_NAME` pick
one by name. Under Wine, a Ryzen's integrated GPU is named "AMD Radeon(TM)
Graphics". One that drives no display is a safe place for tests that could
hang a GPU.

## Known differences

- **Speed.** Wine emulates write watching page by page, so the copies of
  title memory take longer than on Windows.
- **Software rendering does not work.** On lavapipe, Wine cannot handle the
  write faults of VIctory's guarded title memory when lavapipe's own
  threads take them.
- **Wine and vkd3d-proton differ from Windows in a few places VIctory now
  handles:**
  - Wine's HLSL compiler (`D3DCompile`, built on vkd3d-shader) has no
    `RWByteAddressBuffer` methods and does not embed root signatures. So
    VIctory's two shaders read structured buffers of words, and their root
    signatures are made apart.
  - vkd3d-proton refuses an empty pipeline library given a non-null blob
    pointer, and does not check DXIL container hashes.
  - Its DXIL to SPIR-V translation cannot structure a loop left by both a
    break and a return, so each translated program returns from one block.
