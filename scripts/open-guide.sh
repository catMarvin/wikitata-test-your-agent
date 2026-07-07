#!/bin/bash
# open-guide.sh — opens the run-guide window (docked top-right): it loads the
# startup instruction onto the clipboard and walks the launch + paste steps.
HARNESS_VERSION="1.6.10"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
osascript -e "tell application \"Terminal\" to do script \"~/tta/run-guide.sh $PROJECT $RUN_ID\"" >/dev/null
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 14' \
  -e 'tell application "Terminal" to set number of columns of front window to 74' \
  -e 'tell application "Terminal" to set number of rows of front window to 40' \
  -e 'tell application "Terminal" to set position of front window to {sw * 11 div 20, 25}' \
  >/dev/null 2>&1 || true
echo "Guide window is up (top right) — follow its STEP 1 and STEP 2."
