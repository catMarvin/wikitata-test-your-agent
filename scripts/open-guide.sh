#!/bin/bash
# open-guide.sh — opens the LIVE run-guide window docked top-right, clear of
# the MAIN window (left 54%) and the recording window (bottom right). The
# guide is a self-repainting stepper (run-guide.sh) that re-wraps to the
# measured window width every tick, so it is sized in pixels, not columns.
HARNESS_VERSION="1.6.17"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
. "$HOME/tta/theme.conf" 2>/dev/null || THEME=""
osascript -e "tell application \"Terminal\" to do script \"~/tta/run-guide.sh $PROJECT $RUN_ID\"" >/dev/null
[ -n "$THEME" ] && osascript -e "tell application \"Terminal\" to set current settings of front window to settings set \"$THEME\"" >/dev/null 2>&1
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 14' \
  -e 'tell application "Terminal" to set bounds of front window to {sw * 28 div 50, 25, sw - 8, sh * 3 div 5}' \
  >/dev/null 2>&1 || true
echo "Guide window is up (top right) — do what pulses."
