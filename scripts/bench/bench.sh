#!/usr/bin/env bash
# One unattended benchmark run: starts the title with run.sh, passes the
# menus and the opening cutscenes with scripted key presses, follows a fixed
# camera path in game and measures for BENCH_MIN minutes (8 by default),
# then stops the title.
#
#   scripts/bench/bench.sh <name> <game executable> [VAR=value ...]
#
# The VAR=value pairs are exported for that run (VICTORY_BUILD=...,
# VICTORY_CARD_BUFFERS_MB=4096...). Output: $VICTORY_BENCH_DIR/<name>/
# (bench/ in the checkout by default) with run.log and summary.txt, and the
# summary line on standard output.
#
# The camera path needs a pad stand-in that takes scripted keys (victory-
# corgi's base patch 10). Any title already running in VIctory's prefix is
# stopped first. BENCH_MOVE=0 stands still, BENCH_SKIP=0 watches the opening
# cutscenes instead of skipping them.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
name="${1:?usage: scripts/bench/bench.sh <name> <game executable> [VAR=value ...]}"
game="${2:?usage: scripts/bench/bench.sh <name> <game executable> [VAR=value ...]}"
shift 2
minutes="${BENCH_MIN:-8}"
out="${VICTORY_BENCH_DIR:-$ROOT/bench}/$name"
rm -rf "${out:?}"
mkdir -p "$out"
log="$out/run.log"

# The Wine server run.sh's Proton uses, to stop the title: the view-tree
# one when it was made, else Steam's Proton Experimental.
data="${XDG_DATA_HOME:-$HOME/.local/share}/victory"
prefix="$data/proton/pfx"
wineserver="$data/proton-viewtree/files/bin/wineserver"
if [[ ! -x "$wineserver" ]]; then
    wineserver="$(ls "$HOME"/.steam/steam/steamapps/common/Proton\ -\ Experimental/files/bin/wineserver \
        "$HOME"/.local/share/Steam/steamapps/common/Proton\ -\ Experimental/files/bin/wineserver 2>/dev/null | head -1)"
fi
stop_title() { [[ -x "$wineserver" ]] && WINEPREFIX="$prefix" "$wineserver" -k 2>/dev/null; }

stop_title
sleep 2

# Menus: Enter every 10 s for 5 minutes. Opening cutscenes: Enter held 3 s
# every 15 s (holding A skips them). Then the camera path: right stick right
# for 8 s, left for 8 s, forward for 4 s, again and again.
keys="$(python3 -c "print(','.join(f'{s}:Enter' for s in range(20, 301, 10)))")"
if [[ "${BENCH_SKIP:-1}" != 0 ]]; then
    keys="$(python3 -c "print(','.join(f'{s}-{s+3}:Enter' for s in range(20, 301, 15)))")"
fi
if [[ "${BENCH_MOVE:-1}" != 0 ]]; then
    keys+=",$(python3 -c "print(','.join(f'{t}-{t+8}:L,{t+10}-{t+18}:J,{t+20}-{t+24}:W' for t in range(310, 400 + $minutes * 60, 30)))")"
fi

(
    export VICTORY_KEYS="$keys" VICTORY_LIVE_FILE=
    for setting in "$@"; do export "$setting"; done
    exec "$ROOT/run.sh" "$game"
) >"$log" 2>&1 &
title=$!
running() { kill -0 "$title" 2>/dev/null; }
clean() { sed 's/\x1b\[[0-9;]*m//g' "$log"; }

# In game: a frame line with 500 draws a frame or more (6 minutes at most).
ingame=""
for _ in $(seq 1 72); do
    sleep 5
    running || break
    if clean | grep -aqE 'host: [0-9.]+ fps, .*, ([5-9][0-9]{2}|[0-9]{4,}) draws/frame'; then
        ingame="$(date -u +%H:%M:%S)"
        break
    fi
done

hang=0
if [[ -n "$ingame" ]]; then
    for _ in $(seq 1 $((minutes * 12))); do
        sleep 5
        running || break
        (( $(date +%s) - $(stat -c %Y "$log") > 40 )) && hang=1
    done
fi
crash="$(clean | grep -acE 'unhandled exception|DEVICE_REMOVED|device removed|DEVICE_HUNG|X Error of failed request')"
running && stop_title

rates="$("$ROOT/scripts/bench/frame-rates.sh" "$log" "${ingame:-23:59:59}")"
line="$name: $rates; crashes $crash; hang $hang; in game $([[ -n "$ingame" ]] && echo yes || echo no)"
echo "$line" | tee "$out/summary.txt"
