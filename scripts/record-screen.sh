#!/bin/bash
# record-screen.sh — run INSIDE the guest VM, in its own dedicated Terminal
# window (start-recording.sh opens it that way via osascript).
#
# The window IS the recording indicator:
#   - red banner + elapsed clock ticking  = screen IS recording
#   - "NO LONGER BEING RECORDED"          = it is not
#
# On-screen furniture (we control the whole paint):
#   row 1 left  : ▌ SCREEN RECORDING ▐ label chip (red)
#   row 1 right : live disk tracker — run capture size + disk free
#   center      : big BLOCK-GRAPHIC clock (red █ digits) when it fits,
#                 compact one-line clock otherwise
#
# SINGLE-PULSE DISCIPLINE: exactly one window in the suite pulses at a time,
# arbitrated by ~/tta/attention. When it says "recording" (the run guide sets
# it at the 45:00 cap), THIS window pulses CLICK HERE / Ctrl-C; otherwise its
# stop instructions stay steady.
#
# Lines are sliced to the window width CHARACTER-wise (block glyphs are
# multibyte — byte truncation would shred them), so it never wraps into soup.
#
# screencapture -v runs in the FOREGROUND on purpose: backgrounding it makes
# it exit immediately (verified on macOS 15) — only the painter runs in the
# background.
#
# STOP: click this window, press Ctrl-C — the recording finalizes and the
# window switches to the stopped banner with the file listing as proof.
#
# Usage: record-screen.sh [output.mov]   (default ~/tta/recording.mov)
HARNESS_VERSION="1.6.21"
SELF_SHA=$(shasum "$0" 2>/dev/null | cut -c1-8)
OUT="${1:-$HOME/tta/recording.mov}"
ATTNF="$HOME/tta/attention"
export LANG="${LANG:-en_US.UTF-8}"
printf '\033]0;wikiTaTa Test Your Agent : screen recording controller\007'
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

glyph() { # glyph <char> -> sets a b c d e (7-wide, 5 rows, block graphics)
  case "$1" in
    0) a="  ███  "; b=" █   █ "; c=" █   █ "; d=" █   █ "; e="  ███  ";;
    1) a="   █   "; b="  ██   "; c="   █   "; d="   █   "; e="  ███  ";;
    2) a="  ███  "; b=" █   █ "; c="    █  "; d="   █   "; e=" █████ ";;
    3) a=" ████  "; b="     █ "; c="  ███  "; d="     █ "; e=" ████  ";;
    4) a="   ██  "; b="  █ █  "; c=" █  █  "; d=" █████ "; e="    █  ";;
    5) a=" █████ "; b=" █     "; c=" ████  "; d="     █ "; e=" ████  ";;
    6) a="  ███  "; b=" █     "; c=" ████  "; d=" █   █ "; e="  ███  ";;
    7) a=" █████ "; b="     █ "; c="    █  "; d="   █   "; e="   █   ";;
    8) a="  ███  "; b=" █   █ "; c="  ███  "; d=" █   █ "; e="  ███  ";;
    9) a="  ███  "; b=" █   █ "; c="  ████ "; d="     █ "; e="  ███  ";;
    :) a="       "; b="   █   "; c="       "; d="   █   "; e="       ";;
    *) a="       "; b="       "; c="       "; d="       "; e="       ";;
  esac
}

human_kb() { # human_kb <kb> -> e.g. 213M / 2.3G
  if [ "$1" -ge 1048576 ]; then
    printf '%d.%dG' $(( $1 / 1048576 )) $(( ($1 % 1048576) * 10 / 1048576 ))
  else
    printf '%dM' $(( $1 / 1024 ))
  fi
}

START=$(date +%s)
(
  # per-line attributes: n=normal, r=red bold, b=bold, L=label chip (red
  # reverse), y=pulsing highlighter (only while ~/tta/attention == recording)
  RL() { LINES_OUT[${#LINES_OUT[@]}]="$1"; ATTRS_OUT[${#ATTRS_OUT[@]}]=r; }
  NL() { LINES_OUT[${#LINES_OUT[@]}]="$1"; ATTRS_OUT[${#ATTRS_OUT[@]}]=n; }
  BL() { LINES_OUT[${#LINES_OUT[@]}]="$1"; ATTRS_OUT[${#ATTRS_OUT[@]}]=b; }
  LB() { LINES_OUT[${#LINES_OUT[@]}]="$1"; ATTRS_OUT[${#ATTRS_OUT[@]}]=L; }
  YL() { LINES_OUT[${#LINES_OUT[@]}]="$1"; ATTRS_OUT[${#ATTRS_OUT[@]}]=y; }
  F=0; DISK=""; LAST_DU=-1
  while :; do
    F=$(( (F + 1) % 8 ))
    COLS=$(tput cols 2>/dev/null) ; [ -n "$COLS" ] || COLS=80
    ROWS=$(tput lines 2>/dev/null) ; [ -n "$ROWS" ] || ROWS=24
    S=$(( $(date +%s) - START ))
    T="$(printf %02d $((S/60))):$(printf %02d $((S%60)))"
    ATTN=$(cat "$ATTNF" 2>/dev/null)
    PP=$(( S % 2 ))

    # disk tracker: recompute every ~5s (du on ~/tta is cheap)
    if [ $(( S / 5 )) -ne "$LAST_DU" ]; then
      LAST_DU=$(( S / 5 ))
      UK=$(du -sk "$HOME/tta" 2>/dev/null | awk '{print $1}'); [ -n "$UK" ] || UK=0
      FK=$(df -k "$HOME" 2>/dev/null | awk 'NR==2{print $4}'); [ -n "$FK" ] || FK=0
      DISK=" capture $(human_kb "$UK") · disk free $(human_kb "$FK") "
    fi

    LINES_OUT=(); ATTRS_OUT=()
    LB " ▌ SCREEN RECORDING ▐ "
    if [ "$COLS" -ge 52 ] && [ "$ROWS" -ge 16 ]; then
      r1=""; r2=""; r3=""; r4=""; r5=""
      i=0
      while [ $i -lt ${#T} ]; do
        glyph "${T:$i:1}"
        r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
        i=$((i+1))
      done
      # separator colon, then the chase: ONLY a block orbiting an invisible
      # oval (nothing else drawn), one revolution per second (8 steps)
      glyph :
      r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
      a="       "; b="       "; c="       "; d="       "; e="       "
      case $F in
        0) a="   █   ";;  1) b="     █ ";;
        2) c="      █";;  3) d="     █ ";;
        4) e="   █   ";;  5) d=" █     ";;
        6) c="█      ";;  7) b=" █     ";;
      esac
      r1="$r1$a"; r2="$r2$b"; r3="$r3$c"; r4="$r4$d"; r5="$r5$e"
      RL "  ██ REC █  SCREEN RECORDING IN PROGRESS"
      NL "  harness v$HARNESS_VERSION ($SELF_SHA)"
      NL ""
      RL "  $r1"; RL "  $r2"; RL "  $r3"; RL "  $r4"; RL "  $r5"
      NL ""
      if [ "$ATTN" = "recording" ]; then
        YL "  ◀◀ CLICK THIS WINDOW NOW — press Ctrl-C to STOP ◀◀"
        NL "     (the run has hit its cap / is complete)"
      else
        NL "  When testing is complete, stop this recording:"
        BL "  click this window and press Ctrl-C"
        NL "  (or run the run-end line in the main Terminal)."
      fi
    else
      RL " ██ REC █  RECORDING   elapsed $T"
      NL " harness v$HARNESS_VERSION ($SELF_SHA)"
      NL ""
      if [ "$ATTN" = "recording" ]; then
        YL " ◀◀ CLICK HERE — Ctrl-C to STOP ◀◀"
      else
        NL " When testing is complete, stop this"
        BL " recording: click here, press Ctrl-C."
      fi
    fi

    # absolute-position every line, NO newlines; CHARACTER-wise width slice
    row=1
    i=0
    while [ "$i" -lt "${#LINES_OUT[@]}" ]; do
      [ "$row" -gt "$ROWS" ] && break
      line="${LINES_OUT[$i]}"
      line="${line:0:$COLS}"
      case "${ATTRS_OUT[$i]}" in
        r) A='\033[1;31m';;
        b) A='\033[1m';;
        L) A='\033[1;7;31m';;
        y) if [ "$PP" -eq 1 ]; then A='\033[1;30;43m'; else A='\033[1m'; fi;;
        *) A='';;
      esac
      printf '\033[%d;1H\033[2K'"$A"'%s\033[0m' "$row" "$line"
      row=$((row+1))
      i=$((i+1))
    done
    [ "$row" -le "$ROWS" ] && printf '\033[%d;1H\033[J' "$row"
    # disk tracker overlay, right-aligned on row 1 (ASCII-safe width math)
    DCOL=$(( COLS - ${#DISK} + 1 ))
    [ "$DCOL" -gt 26 ] && printf '\033[1;%dH\033[1m%s\033[0m' "$DCOL" "$DISK"
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
printf '\n  \033[1;32m>>> NO LONGER BEING RECORDED <<<\033[0m\n  harness v%s (%s)\n\n' "$HARNESS_VERSION" "$SELF_SHA"
if [ -s "$OUT" ]; then
  ls -l "$OUT"
  printf '\n  \033[1;32mRecording saved.\033[0m You can close this window.\n'
else
  printf '  \033[1;31mWARNING: no recording file was written — report this.\033[0m\n'
fi
