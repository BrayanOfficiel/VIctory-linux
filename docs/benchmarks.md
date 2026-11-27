# Benchmarks

The frame rates in the README come from alternating benchmark series run
on one machine. This page gives the method and every series behind the
current defaults.

## Machine

AMD RX 6950 XT (16 GB, RDNA 2) with RADV from Mesa 26.2.6, Ryzen 9 7900X
(24 threads), 32 GB of DDR5, CachyOS. Proton Experimental with the
view-tree Wine server (`scripts/proton-viewtree.sh`). Series S mode, a
1280x720 window, MangoHud on.

## Method

Each run starts the title, passes the menus and the opening cutscenes with
scripted key presses, then follows a fixed camera path in game (right
stick right for 8 s, left for 8 s, forward for 4 s, repeated) and measures
for 8 minutes. The frame rate is read from VIctory's frame line, once
every 5 seconds, from the moment the title draws more than 500 draws a
frame.

A series runs every configuration in turn, then again, so that the
machine's drift over an evening (memory filling, swap) reaches every
configuration alike. Two runs of the same configuration differ by up to
4 fps, so no single run decides anything.

A change is adopted when it gains 2 fps or more on average and gains in
every round. It is rejected when it loses 2 fps or more. A change in
between is kept only when it fixes the picture or cuts the part of the
frame it targets by 15 % or more.

The tools are not in this repository yet: `bench.sh` (one run),
`serie-ab.sh` (a series) and `bilan.sh` (median and 10th percentile of a
log).

## Series

Medians of each run's frame rate, in frames a second, while moving.

### 2026-11-27 evening: the current defaults

| Configuration | Runs | Mean | 10th percentile | Decision |
|---|---|---|---|---|
| victory-corgi 8b6671c (previous base) | 18.3, 22.3 | 20.3 | 15.2 | replaced |
| victory-corgi 76eebd5 with the Wine class 7 fallback | 22.5, 20.3 | 21.4 | 16.0 | adopted, copies 27.5 to 15.6 ms a frame |
| the same with `VICTORY_WC_NO_BACK=1` | 23.8, 23.3 | 23.6 | 16.4 | adopted, copying back 10.7 to 5.8 ms |
| the same with `VICTORY_TEXTURE_NO_WAIT=0` | 21.7, 22.9 | 22.3 | 16.4 | adopted, fixes oily skin at no cost |

A 40-minute play session with all of them reached 22.6 fps median and
21.0 at the 10th percentile, without a crash.

### 2026-11-27 afternoon

| Configuration | Runs | Mean | 10th percentile | Decision |
|---|---|---|---|---|
| reference | 19.9, 18.8 | 19.4 | 14.9 | |
| `VICTORY_LAND_THREADS=8` | 20.4, 19.2 | 19.8 | 15.0 | neutral |
| `RELAY=1`, `TEXTURE_NO_WAIT=0`, `TEXTURE_POOL=0` together | 19.2, 16.7 | 17.9 | 13.9 | not adopted as a block |

### 2026-11-26

| Configuration | Runs | Mean | 10th percentile | Decision |
|---|---|---|---|---|
| reference | 16.7, 17.6 | 17.1 | 13.4 | |
| Draesia's victory-drae | 17.8, 15.3, 18.9, 14.1 | 16.5 | 12.4 | rejected |
| victory-drae with 4 KiB fetched parts | 18.9, 14.1 | 16.5 | 12.4 | rejected |
| reference | 16.1, 17.7 | 16.9 | 12.7 | |
| CPU power profile `performance` | 14.0, 18.5 | 16.2 | 12.4 | rejected |
