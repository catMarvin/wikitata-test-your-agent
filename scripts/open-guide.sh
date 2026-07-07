#!/bin/bash
# open-guide.sh — opens the run-guide window (docked top-right): it loads the
# startup instruction onto the clipboard and walks the launch + paste steps.
HARNESS_VERSION="1.6.7"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
osascript -e "tell application \"Terminal\" to do script \"~/tta/run-guide.sh $PROJECT $RUN_ID\"" >/dev/null
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
  -e 'tell application "Terminal" to set bounds of front window to {sw * 3 div 5, 25, sw, sh * 11 div 20}' \
  >/dev/null 2>&1 || true
echo "Guide window is up (top right) — follow its STEP 1 and STEP 2."
