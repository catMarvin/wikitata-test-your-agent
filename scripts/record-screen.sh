#!/bin/bash
# record-screen.sh — run INSIDE the guest VM, in its own dedicated Terminal
# window (the runbook's recording step opens it that way via osascript).
#
# The window IS the recording indicator:
#   - banner + a big ASCII clock counting elapsed time  = screen IS recording
#   - "NO LONGER BEING RECORDED" (clock gone)           = it is not
#
# screencapture -v runs in the FOREGROUND on purpose: backgrounding it makes
# it exit immediately (verified live on macOS 15) — only the timer runs in
# the background, painting the clock onto this window every second.
#
# STOP: click this window, press Ctrl-C — the recording finalizes and the
# window switches to the stopped banner with the file listing as proof.
#
# Usage: record-screen.sh [output.mov]   (default ~/tta/recording.mov)
OUT="${1:-$HOME/tta/recording.mov}"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

clear
printf '\n  >>> SCREEN RECORDING IN PROGRESS <<<\n\n'
printf '  This window IS the indicator. Leave it open.\n'
printf '  TO STOP: click this window, press Ctrl-C.\n'

START=$(date +%s)
(
  while :; do
    S=$(( $(date +%s) - START ))
    T="$(printf %02d $((S/60))):$(printf %02d $((S%60)))"
    r1=""; r2=""; r3=""; r4=""; r5=""
    i=0
    while [ $i -lt ${#T} ]; do
      ch=${T:$i:1}
      case $ch in
        0) a="  ###  "; b=" #   # "; c=" #   # "; d=" #   # "; e="  ###  ";;
        1) a="   #   "; b="  ##   "; c="   #   "; d="   #   "; e="  ###  ";;
        2) a="  ###  "; b=" #   # "; c="    #  "; d="   #   "; e=" ##### ";;
        3) a=" ####  "; b="     # "; c="  ###  "; d="     # "; e=" ####  ";;
        4) a="   ##  "; b="  # #  "; c=" #  #  "; d=" ##### "; e="    #  ";;
        5) a=" ##### "; b=" #     "; c=" ####  "; d="     # "; e=" ####  ";;
        6) a="  ###  "; b=" #     "; c=" ####  "; d=" #   # "; e="  ###  ";;
        7) a=" ##### "; b="     # "; c="    #  "; d="   #   "; e="   #   ";;
        8) a="  ###  "; b=" #   # "; c="  ###  "; d=" #   # "; e="  ###  ";;
        9) a="  ###  "; b=" #   # "; c="  #### "; d="     # "; e="  ###  ";;
        :) a="       "; b="   #   "; c="       "; d="   #   "; e="       ";;
        *) a="       "; b="       "; c="       "; d="       "; e="       ";;
      esac
      r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
      i=$((i+1))
    done
    printf '\033[7;1H\033[2K  RECORDING — ELAPSED TIME SHOWN HERE:\n\033[2K\n\033[2K  %s\n\033[2K  %s\n\033[2K  %s\n\033[2K  %s\n\033[2K  %s\n\033[2K\n\033[2K  When testing is complete, stop this recording:\n\033[2K  click this window and press Ctrl-C\n\033[2K  (or run the run-end line in the main Terminal).\n' \
      "$r1" "$r2" "$r3" "$r4" "$r5"
    sleep 1
  done
) &
TIMER=$!

trap 'true' INT
screencapture -v "$OUT"
kill "$TIMER" 2>/dev/null
wait "$TIMER" 2>/dev/null

clear
printf '\n  >>> NO LONGER BEING RECORDED <<<\n\n'
if [ -s "$OUT" ]; then
  ls -l "$OUT"
  printf '\n  Recording saved. You can close this window.\n'
else
  printf '  WARNING: no recording file was written — report this.\n'
fi
