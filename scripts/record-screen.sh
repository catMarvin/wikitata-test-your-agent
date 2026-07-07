#!/bin/bash
# record-screen.sh — run INSIDE the guest VM, in its own dedicated Terminal
# window (the runbook's recording step opens it that way via osascript).
#
# The window IS the recording indicator:
#   - banner + elapsed clock ticking  = screen IS recording
#   - "NO LONGER BEING RECORDED"      = it is not
#
# The display MEASURES the window every second (tput cols/lines) and adapts:
# big ASCII clock when it fits, compact one-line clock otherwise; every line
# is truncated to the window width, so it never wraps into soup.
#
# screencapture -v runs in the FOREGROUND on purpose: backgrounding it makes
# it exit immediately (verified on macOS 15) — only the painter runs in the
# background.
#
# STOP: click this window, press Ctrl-C — the recording finalizes and the
# window switches to the stopped banner with the file listing as proof.
#
# Usage: record-screen.sh [output.mov]   (default ~/tta/recording.mov)
HARNESS_VERSION="1.6.12"
SELF_SHA=$(shasum "$0" 2>/dev/null | cut -c1-8)
OUT="${1:-$HOME/tta/recording.mov}"
printf '\033]0;wikiTaTa Test Your Agent : screen recording controller\007'
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

glyph() { # glyph <char> -> sets a b c d e (7-wide, 5 rows)
  case "$1" in
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
}

START=$(date +%s)
(
  F=0
  while :; do
    F=$(( (F + 1) % 8 ))
    COLS=$(tput cols 2>/dev/null) ; [ -n "$COLS" ] || COLS=80
    ROWS=$(tput lines 2>/dev/null) ; [ -n "$ROWS" ] || ROWS=24
    S=$(( $(date +%s) - START ))
    T="$(printf %02d $((S/60))):$(printf %02d $((S%60)))"

    LINES_OUT=()
    if [ "$COLS" -ge 52 ] && [ "$ROWS" -ge 16 ]; then
      r1=""; r2=""; r3=""; r4=""; r5=""
      i=0
      while [ $i -lt ${#T} ]; do
        glyph "${T:$i:1}"
        r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
        i=$((i+1))
      done
      # separator colon, then the chase: ONLY a period orbiting an invisible
      # oval (nothing else drawn), one revolution per second (8 steps)
      glyph :
      r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
      a="       "; b="       "; c="       "; d="       "; e="       "
      case $F in
        0) a="   .   ";;  1) b="     . ";;
        2) c="      .";;  3) d="     . ";;
        4) e="   .   ";;  5) d=" .     ";;
        6) c=".      ";;  7) b=" .     ";;
      esac
      r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
      LINES_OUT=( \
        "" \
        "  >>> SCREEN RECORDING IN PROGRESS <<<" \
        "  harness v$HARNESS_VERSION ($SELF_SHA)" \
        "" \
        "  RECORDING — ELAPSED TIME SHOWN HERE:" \
        "" \
        "  $r1" "  $r2" "  $r3" "  $r4" "  $r5" \
        "" \
        "  When testing is complete, stop this recording:" \
        "  click this window and press Ctrl-C" \
        "  (or run the run-end line in the main Terminal)." )
    else
      LINES_OUT=( \
        "" \
        " >>> RECORDING <<<   elapsed $T" \
        " harness v$HARNESS_VERSION ($SELF_SHA)" \
        "" \
        " When testing is complete, stop this" \
        " recording: click here, press Ctrl-C." )
    fi

    # absolute-position every line, NO newlines: scrolling is impossible at
    # any window size (15 lines + newlines in a 15-row window scrolled one
    # line per tick — the v1.6 soup). Lines past the window bottom are skipped.
    row=1
    for line in "${LINES_OUT[@]}"; do
      [ "$row" -gt "$ROWS" ] && break
      printf '\033[%d;1H\033[2K%.*s' "$row" "$COLS" "$line"
      row=$((row+1))
    done
    [ "$row" -le "$ROWS" ] && printf '\033[%d;1H\033[J' "$row"
    sleep 0.12
  done
) &
TIMER=$!

trap 'true' INT
clear
screencapture -v "$OUT"
kill "$TIMER" 2>/dev/null
wait "$TIMER" 2>/dev/null

clear
printf '\n  >>> NO LONGER BEING RECORDED <<<\n  harness v%s (%s)\n\n' "$HARNESS_VERSION" "$SELF_SHA"
if [ -s "$OUT" ]; then
  ls -l "$OUT"
  printf '\n  Recording saved. You can close this window.\n'
else
  printf '  WARNING: no recording file was written — report this.\n'
fi
