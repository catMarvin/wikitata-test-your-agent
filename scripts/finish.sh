#!/bin/bash
# finish.sh — run when the agent DECLARES DONE (recording still rolling).
# The elegant wrap (Todd S718): no manual dev-server ask, no Safari ask,
# no Ctrl-C hunt. It:
#   1. stamps agent_done;
#   2. starts the project's dev server (npm run dev, preview fallback) and
#      opens Safari on it — the finished app gets TTA_SHOW_SECS (default 20s)
#      ON CAMERA;
#   3. stops the recording, stamps run_end, prints proof + export command
#      (via end-run.sh — ONE wrap path).
# Run it in a NEW Terminal window (Command+N) — Claude Code owns MAIN.
HARNESS_VERSION="1.6.20"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
SHOW_SECS="${TTA_SHOW_SECS:-20}"
tl() { printf '%s\tguest\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$HOME/tta/run-times.log"; }

printf '\033]0;wikiTaTa Test Your Agent : FINISH\007'
echo ""
printf '\033[1;7;36m ▌ FINISH ▐  wrapping the run \033[0m\n'
echo "  harness v$HARNESS_VERSION - run: $RUN_ID"
echo ""
tl agent_done_finish_started

cd "$HOME/challenge/$PROJECT" 2>/dev/null || { echo "  FAIL: no ~/challenge/$PROJECT — report this."; exit 1; }
URL=""
if [ -f package.json ] && grep -q '"dev"' package.json; then
  echo "  starting the dev server (npm run dev)..."
  (npm run dev > "$HOME/tta/devserver.log" 2>&1 &)
  sleep 6
  URL=$(grep -o 'http://localhost:[0-9]*' "$HOME/tta/devserver.log" | head -1)
fi
if [ -z "$URL" ] && [ -f package.json ] && grep -q '"preview"' package.json; then
  echo "  no URL from dev - trying npm run preview..."
  (npm run preview > "$HOME/tta/devserver.log" 2>&1 &)
  sleep 5
  URL=$(grep -o 'http://localhost:[0-9]*' "$HOME/tta/devserver.log" | head -1)
fi

if [ -n "$URL" ]; then
  echo "  opening Safari on $URL"
  printf '\033[1;32m  the finished app is ON CAMERA for %s seconds...\033[0m\n' "$SHOW_SECS"
  open -a Safari "$URL"
  tl "app_on_camera $URL"
  sleep "$SHOW_SECS"
elif [ -f index.html ]; then
  echo "  no dev server found - opening index.html directly"
  open -a Safari "index.html"
  tl app_on_camera_static
  sleep "$SHOW_SECS"
else
  echo "  WARNING: nothing to open (no dev/preview script, no index.html) - skipping showcase"
  tl finish_no_showcase
fi

echo ""
echo "  stopping the recording + finalizing..."
"$HOME/tta/end-run.sh"
