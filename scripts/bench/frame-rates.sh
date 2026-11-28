#!/usr/bin/env bash
# Frame rate of a run in game, from VIctory's frame lines with 500 draws a
# frame or more (menus and loading screens draw fewer):
#   scripts/bench/frame-rates.sh <run.log> [HH:MM:SS, UTC: count from then]
# Prints the median, the 10th percentile, the least and most, the count.
set -u
sed 's/\x1b\[[0-9;]*m//g' "$1" | awk -v t0="${2:-00:00:00}" '
    /host: [0-9.]+ fps, / {
        split($1, a, "T"); if (substr(a[2], 1, 8) < t0) next
        f = ""; d = 0
        for (i = 1; i <= NF; i++) { if ($i == "fps,") f = $(i-1); if ($i == "draws/frame,") d = $(i-1) + 0 }
        if (f != "" && d >= 500) print f
    }' | sort -n | awk '{ a[NR] = $1 } END {
        if (NR == 0) { print "no frame line in game"; exit 1 }
        printf "median %.1f fps, 10th percentile %.1f, min %.1f, max %.1f (%d lines)\n", a[int(NR/2)+1], a[int(NR/10)+1], a[1], a[NR], NR }'
