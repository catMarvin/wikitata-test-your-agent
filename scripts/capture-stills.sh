#!/bin/bash
# capture-stills.sh — run INSIDE the guest VM during a challenge run.
# Takes a full-screen PNG every INTERVAL seconds into ~/tta/stills/ and keeps
# manifest.json current so tools/run-viewer/index.html can play the flip-book.
# Usage:  ./capture-stills.sh &          (default 30s)
#         INTERVAL=15 ./capture-stills.sh &
set -euo pipefail
INTERVAL="${INTERVAL:-30}"
DIR="$HOME/tta/stills"
mkdir -p "$DIR"
n=0
while true; do
  n=$((n+1))
  f=$(printf "%04d.png" "$n")
  screencapture -x "$DIR/$f" 2>/dev/null || true
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  # regenerate manifest (stills relative to the manifest's own directory)
  {
    echo '{ "run_id": "'"${RUN_ID:-unnamed-run}"'", "video": "recording.mov", "stills": ['
    first=1
    for p in "$DIR"/*.png; do
      b=$(basename "$p")
      [ $first -eq 1 ] || printf ','
      printf '{"file":"stills/%s"}' "$b"
      first=0
    done
    echo '] }'
  } > "$HOME/tta/manifest.json"
  echo "$ts  captured $f"
  sleep "$INTERVAL"
done
