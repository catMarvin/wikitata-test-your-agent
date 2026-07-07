#!/bin/bash
# start-recording.sh — opens the recording window (full-screen capture with a
# live elapsed clock, docked bottom-right) and VERIFIES it, printing an
# explicit YES-continue / NO-stop verdict.
HARNESS_VERSION="1.6.5"
osascript -e 'tell application "Terminal" to do script "~/tta/record-screen.sh"' >/dev/null
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
  -e 'tell application "Terminal" to set bounds of front window to {sw * 3 div 5, sh * 11 div 20, sw, sh - 80}' \
  >/dev/null 2>&1 || true
sleep 3
if pgrep -x screencapture >/dev/null; then
  echo ">>> YES: RECORDING IS LIVE — next:  ~/tta/open-guide.sh <<<"
else
  echo ">>> NO: NOT RECORDING — STOP HERE. Approve the Screen Recording"
  echo ">>> permission (password: admin), then run this again. <<<"
fi
