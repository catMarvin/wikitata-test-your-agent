#!/bin/bash
# begin.sh — the guided run wizard. Run this ONE command in a fresh VM
# Terminal window. It PAGES like an installer: every screen is repainted
# fresh (block-graphic header + colored step tracker + ONE pulsing
# highlighter "PRESS RETURN" action) — the operator never sees a scrollback
# wall, and the recording only ever shows the current step.
HARNESS_VERSION="1.6.13"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
export LANG="${LANG:-en_US.UTF-8}"

focus_main() {
  osascript -e 'tell application "Terminal" to activate' \
    -e 'tell application "Terminal" to set index of (first window whose name contains "MAIN") to 1' \
    >/dev/null 2>&1 || true
}
printf '\033]0;wikiTaTa Test Your Agent : MAIN — type here\007'
# MAIN owns the LEFT 54% of the screen; guide top-right, recording bottom-right.
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
  -e 'tell application "Terminal" to set bounds of front window to {0, 25, sw * 27 div 50, sh - 80}' \
  >/dev/null 2>&1 || true

ROW=1
PULSER=""
say()  { printf '%s\n' "$1"; ROW=$((ROW+1)); }
bold() { printf '\033[1m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }
cy()   { printf '\033[1;36m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }
grn()  { printf '\033[1;32m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }
hl()   { printf '\033[1;30;43m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }

page_top() { # $1 = current step 1..4 (0 = welcome page, no tracker)
  printf '\033[2J\033[H'; ROW=1
  say ""
  cy  " ╔══════════════════════════════════════════════════════════════════╗"
  cy  " ║   wikiTaTa \"Test Your Agent\" ▪ guided run wizard                  ║"
  cy  " ╚══════════════════════════════════════════════════════════════════╝"
  say "   run: $RUN_ID  ·  harness v$HARNESS_VERSION"
  say ""
  if [ "$1" -gt 0 ]; then
    local i=1 name
    for name in "stills camera (one photo every 30s)" \
                "screen recording of the whole run" \
                "run guide + instruction on the clipboard" \
                "launch the agent (Claude Code)"; do
      if [ "$i" -lt "$1" ]; then grn "     ✔ STEP $i  $name"
      elif [ "$i" -eq "$1" ]; then hl "     ▶ STEP $i  $name "
      else say "     ▷ STEP $i  $name"; fi
      i=$((i+1))
    done
    say ""
  fi
}

press_return() { # $1 pulses (~1s highlighter <-> bold) until Return; $2.. below
  local first="$1"; shift
  local prow=$((ROW+1)) extra
  say ""
  say " $first"
  for extra in "$@"; do say "   $extra"; done
  say ""
  ( while :; do
      printf '\033[%d;1H\033[2K\033[1;30;43m %s\033[0m' "$prow" "$first"; sleep 0.9
      printf '\033[%d;1H\033[2K\033[1m %s\033[0m'       "$prow" "$first"; sleep 0.9
    done ) 2>/dev/null &
  PULSER=$!
  printf '\033[%d;1H' "$ROW"
  if ! read -rs; then
    kill "$PULSER" 2>/dev/null; printf '\033[?25h\033[0m\n'; exit 1
  fi
  kill "$PULSER" 2>/dev/null; wait "$PULSER" 2>/dev/null
  printf '\033[%d;1H\033[2K\033[1;32m ✔%s\033[0m' "$prow" "${first#?}"
  printf '\033[%d;1H' "$ROW"
}

printf '\033[?25l'
trap 'printf "\033[?25h\033[0m"; [ -n "$PULSER" ] && kill "$PULSER" 2>/dev/null' EXIT

# ---- PAGE: welcome ----
page_top 0
cy  "   █     █ ██████ █       █████  ████  █     █ ██████"
cy  "   █     █ █      █      █      █    █ ██   ██ █"
cy  "   █  █  █ █████  █      █      █    █ █ █ █ █ █████"
cy  "   █ █ █ █ █      █      █      █    █ █  █  █ █"
cy  "    █   █  ██████ ██████  █████  ████  █     █ ██████"
say ""
bold "   ...to the wikiTaTa \"Test Your Agent\" testing suite."
say ""
say "   This wizard prepares and records your test run, then launches"
say "   the agent. It moves ONE page at a time, and each page asks for"
say "   exactly ONE thing: when the pulsing highlighter says PRESS"
say "   RETURN, you press the Return key. That is it."
say ""
say "   What it sets up, in order:"
say "     1. stills camera - one PNG of the screen every 30 seconds"
say "        (these become the flip-book replay of your run);"
say "     2. screen recording - a movie of the ENTIRE screen"
say "        (a clock window shows you it is live);"
say "     3. run guide - opens top right and loads your one startup"
say "        instruction onto the clipboard;"
say "     4. the agent itself - Claude Code launches right here."
press_return "▶▶ PRESS RETURN to begin ◀◀"

# ---- STEP 1: stills camera (automatic; fresh capture state on re-run) ----
pkill -f capture-stills.sh 2>/dev/null; pkill -INT -x screencapture 2>/dev/null; sleep 1
# a PRIOR run's stamps would fast-forward the self-advancing guide past its
# LAUNCH/PASTE panels — rotate them aside (never delete: they are evidence)
if grep -q -e claude_launch -e run_end "$HOME/tta/run-times.log" 2>/dev/null; then
  mv "$HOME/tta/run-times.log" "$HOME/tta/run-times.prev.$(date +%s).log"
fi
{ RUN_ID="$RUN_ID" INTERVAL=30 "$HOME/tta/capture-stills.sh" > "$HOME/tta/stills.log" 2>&1 & }
"$HOME/tta/tl" stills_started

# ---- PAGE: step 2, screen recording ----
page_top 2
grn "   STEP 1 needed nothing from you - the stills camera is already"
grn "   rolling (one photo of the screen every 30 seconds)."
press_return "▶▶ PRESS RETURN - this will START THE SCREEN RECORDING ◀◀" \
             "A clock window opens bottom right; the whole screen records" \
             "until the end of the run."
"$HOME/tta/start-recording.sh" >/dev/null
until pgrep -x screencapture >/dev/null; do
  page_top 2
  bold "   The recording did NOT start - macOS is asking for permission."
  say  ""
  say  "   Approve the Screen Recording permission (password: admin),"
  say  "   let Terminal quit and reopen if it asks, then come back here."
  press_return "▶▶ PRESS RETURN to try the recording again ◀◀"
  "$HOME/tta/start-recording.sh" >/dev/null
done
focus_main

# ---- PAGE: step 3, run guide + clipboard ----
page_top 3
grn "   STEP 2 DONE - the screen recording is LIVE (see the clock"
grn "   window, bottom right)."
press_return "▶▶ PRESS RETURN - this will OPEN THE RUN GUIDE window ◀◀" \
             "It docks top right and puts the startup instruction on the" \
             "clipboard, ready to paste."
"$HOME/tta/open-guide.sh" >/dev/null 2>&1
focus_main

# ---- PAGE: step 4, launch the agent ----
page_top 4
grn "   STEP 3 DONE - the guide is up (top right); your instruction is"
grn "   ON THE CLIPBOARD."
say ""
say "   Next, the agent (Claude Code) launches RIGHT HERE. When it"
say "   opens: press Command+V, then Return."
bold "   ▶▶ THAT Return starts the clock. BASIC persona from then on. ◀◀"
press_return "▶▶ PRESS RETURN - this will LAUNCH THE AGENT (Claude Code) ◀◀"
printf '\033[?25h\033[0m\033[2J\033[H'
"$HOME/tta/tl" claude_launch
cd "$HOME/challenge/$PROJECT" && exec claude
