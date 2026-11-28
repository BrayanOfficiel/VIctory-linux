#!/usr/bin/env bash
# An alternating series: every configuration runs in turn (scripts/bench/
# bench.sh), then again, so that the machine's drift over the evening
# (memory filling, swap) reaches every configuration alike.
#
#   scripts/bench/series.sh <rounds> <game executable> <name>=<VAR=v,VAR=v> [...]
#
#   scripts/bench/series.sh 2 /games/title/game.exe \
#       ref=VICTORY_BUILD=victory-corgi \
#       card4096=VICTORY_BUILD=victory-corgi,VICTORY_CARD_BUFFERS_MB=4096
#
# Output: $VICTORY_BENCH_DIR/series-<date>/ (bench/ in the checkout by
# default), each run's folder and series.txt, which ends with each
# configuration's runs, their mean and spread. Two runs of the same
# configuration differ by up to 4 fps: compare means, not single runs.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
rounds="${1:?usage: scripts/bench/series.sh <rounds> <game executable> <name>=<VAR=v,...> [...]}"
game="${2:?usage: scripts/bench/series.sh <rounds> <game executable> <name>=<VAR=v,...> [...]}"
shift 2
stamp="series-$(date +%m%d-%H%M)"
export VICTORY_BENCH_DIR="${VICTORY_BENCH_DIR:-$ROOT/bench}"
out="$VICTORY_BENCH_DIR/$stamp"
mkdir -p "$out"
names=() specs=()
for arg in "$@"; do names+=("${arg%%=*}"); specs+=("${arg#*=}"); done

for ((round = 1; round <= rounds; round++)); do
    for i in "${!names[@]}"; do
        IFS=',' read -r -a settings <<<"${specs[$i]}"
        echo "[$(date +%H:%M)] round $round: ${names[$i]} (${specs[$i]})" | tee -a "$out/series.txt"
        "$ROOT/scripts/bench/bench.sh" "$stamp/${names[$i]}-$round" "$game" "${settings[@]}" | tee -a "$out/series.txt"
    done
done

echo "== by configuration (median of each run)" | tee -a "$out/series.txt"
for name in "${names[@]}"; do
    grep -hE "^$stamp/$name-[0-9]+: " "$out"/*/summary.txt 2>/dev/null |
        sed -E 's/.*median ([0-9.]+) fps, 10th percentile ([0-9.]+).*/\1 \2/' |
        awk -v n="$name" '{ m[NR] = $1; s += $1; q += $1 * $1; k += $2 }
            END { if (NR) { mean = s / NR; sd = sqrt(q / NR - mean * mean)
                printf "%-14s %d runs:", n, NR; for (i = 1; i <= NR; i++) printf " %.1f", m[i]
                printf "; mean %.1f fps, spread %.1f; 10th percentile %.1f\n", mean, sd, k / NR } }' |
        tee -a "$out/series.txt"
done
