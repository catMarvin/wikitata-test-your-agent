#!/bin/bash
# begin.sh — the guided run wizard. Run this ONE command in a fresh VM
# Terminal window; from here every step is "[ PRESS RETURN ]".
HARNESS_VERSION="1.6.8"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }

focus_main() {
  osascript -e 'tell application "Terminal" to activate' \
    -e 'tell application "Terminal" to set index of (first window whose name contains "MAIN") to 1' \
    >/dev/null 2>&1 || true
}
printf '\033]0;wikiTaTa Test Your Agent : MAIN — type here\007'
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
  -e 'tell application "Terminal" to set bounds of front window to {0, 25, sw * 3 div 5, sh - 80}' \
  >/dev/null 2>&1 || true

clear
echo ""
echo " wikiTaTa — TEST YOUR AGENT       run: $RUN_ID   harness v$HARNESS_VERSION"
echo " ======================================================================"
echo ""

# fresh capture state (safe to re-run begin.sh any time before the run)
pkill -f capture-stills.sh 2>/dev/null; pkill -INT -x screencapture 2>/dev/null; sleep 1
{ RUN_ID="$RUN_ID" INTERVAL=30 "$HOME/tta/capture-stills.sh" > "$HOME/tta/stills.log" 2>&1 & }
"$HOME/tta/tl" stills_started
echo " STEP 1  DONE ✓  Automatic stills camera is rolling"
echo "                 (it saves one photo of the screen every 30 seconds)."
echo ""
echo " [ PRESS RETURN — this will START THE SCREEN RECORDING.               ]"
echo " [ A clock window will open; the whole screen records until the end. ]"
read -r
"$HOME/tta/start-recording.sh"
until pgrep -x screencapture >/dev/null; do
  echo ""
  echo " [ Approve the Screen Recording permission (password: admin),        ]"
  echo " [ then PRESS RETURN to try again.                                   ]"
  read -r
  "$HOME/tta/start-recording.sh"
done
focus_main
echo ""
echo " STEP 2  DONE ✓  Screen recording is LIVE (see the clock window)."
echo ""
echo " [ PRESS RETURN — this will OPEN THE RUN GUIDE window and put the     ]"
echo " [ startup instruction on the clipboard, ready to paste.              ]"
read -r
"$HOME/tta/open-guide.sh" >/dev/null 2>&1
focus_main
echo " STEP 3  DONE ✓  Guide is up; the instruction is ON YOUR CLIPBOARD."
echo ""
echo " [ PRESS RETURN — this will LAUNCH THE AGENT (Claude Code) right      ]"
echo " [ here. When it opens: press Command+V, then Return.                 ]"
echo " [ >>> THAT Return starts the clock. BASIC persona from then on. <<<  ]"
read -r
"$HOME/tta/tl" claude_launch
cd "$HOME/challenge/$PROJECT" && exec claude
