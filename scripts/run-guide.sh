#!/bin/bash
# run-guide.sh — the LIVE run guide. Runs in its own Terminal window (opened
# by open-guide.sh, docked top-right). The operator NEVER types here: the
# window paints ONE panel at a time — only what to do RIGHT NOW — and
# advances ITSELF by watching the run's real signals:
#
#   LAUNCH   waiting for the claude_launch stamp in ~/tta/run-times.log
#   PASTE    Claude Code is up; waiting for agent transcript activity
#            (the operator's paste + Return) under ~/.claude/projects
#   LIVE     the run is timed; persona reference card stays up
#   WRAP-UP  the screen recording stopped -> show the end-run step
#   DONE     run_end stamped -> export instructions
#
# The "DO THIS NOW" box PULSES gently (~1s bold <-> reverse). No fast blink.
# Painting is absolute-positioned (same discipline as record-screen.sh), so
# scrolling soup is impossible at any window size; text re-wraps to the
# measured width every tick.
#
# Unchanged duties: puts the startup instruction ON THE CLIPBOARD and stamps
# guide_opened_clipboard_loaded into the timing log.
#
# Usage: run-guide.sh [project] [run-id]   (defaults: calculator, calc-A-basic-1)
HARNESS_VERSION="1.6.12"
SELF_SHA=$(shasum "$0" 2>/dev/null | cut -c1-8)
PROJECT="${1:-calculator}"
RUN_ID="${2:-calc-A-basic-1}"
RAW="https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main"
INSTR="$HOME/tta/startup-instruction.txt"
TLOG="$HOME/tta/run-times.log"
MARK="$HOME/tta/.claude-launch.marker"

mkdir -p "$HOME/tta"
# offline-first: vm-setup already staged the instruction; network is a fallback only
if [ ! -s "$INSTR" ]; then
  if ! curl -fsSL "$RAW/instructions/${PROJECT}.txt" -o "$INSTR"; then
    echo "FAIL: instruction not staged and download failed (check the VM's network) — report this."
    exit 1
  fi
fi
pbcopy < "$INSTR" || { echo "FAIL: could not load the clipboard — report this."; exit 1; }
printf '%s\tguest\tguide_opened_clipboard_loaded\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"

printf '\033]0;wikiTaTa Test Your Agent : RUN GUIDE — do what pulses\007'
printf '\033[?25l'
trap 'printf "\033[?25h\033[0m"; exit 0' INT TERM

rm -f "$MARK"
STATE=launch
LIVE_AT=0
TICK=0

# Panel line queue: L = normal, BL = bold, PL = pulsing (the DO-THIS-NOW box).
L()  { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=n; }
BL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=b; }
PL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=p; }

header() { # $1 = current phase 1..4 for the tracker
  local out="  " i=1 name mark
  L ""
  BL " ================================================================"
  BL "  wikiTaTa TEST YOUR AGENT - RUN GUIDE"
  L  "  run: $RUN_ID  -  harness v$HARNESS_VERSION ($SELF_SHA)"
  BL " ================================================================"
  L ""
  for name in "LAUNCH" "PASTE" "LIVE-RUN" "WRAP-UP"; do
    if [ "$i" -lt "$1" ]; then mark="[x]"
    elif [ "$i" -eq "$1" ]; then mark="[>]"
    else mark="[ ]"; fi
    out="$out$mark $name   "
    i=$((i+1))
  done
  BL "$out"
  L ""
}

while :; do
  TICK=$((TICK+1))
  P=$(( (TICK / 3) % 2 ))                       # gentle pulse: ~0.9s per half
  COLS=$(tput cols 2>/dev/null); [ -n "$COLS" ] || COLS=80
  ROWS=$(tput lines 2>/dev/null); [ -n "$ROWS" ] || ROWS=24
  TW=$(( COLS - 1 ))

  # ---- advance the state machine from the run's real signals ----
  if grep -q "run_end" "$TLOG" 2>/dev/null; then
    STATE=done
  else
    case "$STATE" in
      launch)
        if grep -q "claude_launch" "$TLOG" 2>/dev/null; then
          touch "$MARK"; STATE=paste
        fi;;
      paste)
        if [ -d "$HOME/.claude/projects" ] && \
           [ -n "$(find "$HOME/.claude/projects" -name '*.jsonl' -newer "$MARK" -size +4k 2>/dev/null | head -1)" ]; then
          STATE=live; LIVE_AT=$(date +%s)
          printf '%s\tguest\trun_live_detected\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"
        fi;;
      live)
        if ! pgrep -x screencapture >/dev/null 2>&1; then
          STATE=wrapup
          printf '%s\tguest\tguide_saw_recording_stop\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"
        fi;;
    esac
  fi

  # ---- build the current panel ----
  LINES=(); ATTRS=()
  case "$STATE" in
    launch)
      header 1
      BL "  WHAT IS HAPPENING NOW"
      L  "    Your startup instruction is already ON THE CLIPBOARD of"
      L  "    this Mac. (It is the only steering you ever give the agent.)"
      L  "    The wizard in the MAIN window (left) is ready to launch"
      L  "    Claude Code - the agent you are testing."
      L  ""
      PL "  +-------------------------------------------------------------+"
      PL "  |  DO THIS NOW:  go to the MAIN window and PRESS RETURN       |"
      PL "  +-------------------------------------------------------------+"
      L  ""
      L  "    That Return launches the agent. No login is needed."
      L  "    This guide notices by itself and shows your next move."
      L  ""
      L  "    (Fallback, only if the wizard is not running:"
      L  "      ~/tta/tl claude_launch; cd ~/challenge/$PROJECT && claude )"
      ;;
    paste)
      header 2
      BL "  WHAT IS HAPPENING NOW"
      L  "    Claude Code is starting in the MAIN window (left)."
      L  ""
      PL "  +-------------------------------------------------------------+"
      PL "  |  DO THIS NOW:  click into Claude Code, press Command+V,     |"
      PL "  |                then press Return.                           |"
      PL "  +-------------------------------------------------------------+"
      L  ""
      BL "    The moment you press Return, the run is LIVE and timed."
      L  ""
      L  "    Clipboard got overwritten? Reload it any time with:"
      L  "      pbcopy < ~/tta/startup-instruction.txt"
      ;;
    live)
      S=$(( $(date +%s) - LIVE_AT ))
      ET="$(printf %02d $((S/60))):$(printf %02d $((S%60)))"
      header 3
      PL "  <<< THE RUN IS LIVE - elapsed $ET - your persona: BASIC >>>"
      L  ""
      BL "  YOUR ONLY MOVES WHILE THE RUN IS LIVE:"
      L  "    - Agent asks a question?   Shortest sensible answer."
      L  "    - Permission prompt?       Approve it. That is normal use."
      L  "    - NEVER suggest features, tools, designs, or approaches."
      L  "    - Agent idle ~60s with no question?  Type exactly:  continue"
      L  "    - Jot down anything you type, with a rough time."
      L  ""
      L  "  THE RUN ENDS when the agent declares done - or at 45:00,"
      L  "  whichever comes first. Then stop the recording:"
      L  "    click the recording window (bottom right), press Ctrl-C."
      L  "  This guide will show the wrap-up steps by itself."
      ;;
    wrapup)
      header 4
      BL "  WHAT IS HAPPENING NOW"
      L  "    The screen recording has stopped."
      L  ""
      PL "  +-------------------------------------------------------------+"
      PL "  |  DO THIS NOW:  open a NEW Terminal window (Command+N)       |"
      PL "  |                and run:   ~/tta/end-run.sh                  |"
      PL "  +-------------------------------------------------------------+"
      L  ""
      L  "    That stamps the end time, finalizes the recording file,"
      L  "    and prints the proof + the export command."
      ;;
    done)
      header 4
      BL "  ALL DONE - THE RUN IS COMPLETE"
      L  ""
      L  "    The end time is stamped and the recording is finalized"
      L  "    (proof was printed where you ran end-run.sh)."
      L  ""
      L  "    Next, on the VM HOST (not inside this VM):"
      BL "      cd ~/tta-runs/staging && ./export-run.sh run-$RUN_ID $RUN_ID"
      L  ""
      L  "    You can close this window."
      ;;
  esac

  # ---- paint: absolute-position every line, truncate to width, no newlines ----
  row=1
  i=0
  while [ "$i" -lt "${#LINES[@]}" ]; do
    [ "$row" -gt "$ROWS" ] && break
    case "${ATTRS[$i]}" in
      p) if [ "$P" -eq 1 ]; then A='\033[1;7m'; else A='\033[1m'; fi;;
      b) A='\033[1m';;
      *) A='';;
    esac
    printf '\033[%d;1H\033[2K'"$A"'%.*s\033[0m' "$row" "$TW" "${LINES[$i]}"
    row=$((row+1))
    i=$((i+1))
  done
  [ "$row" -le "$ROWS" ] && printf '\033[%d;1H\033[J' "$row"
  sleep 0.3
done
