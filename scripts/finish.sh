#!/bin/bash
# finish.sh — run when the agent DECLARES DONE (recording still rolling).
# The elegant wrap (Todd S718): no manual dev-server ask, no Safari ask,
# no Ctrl-C hunt. It:
#   1. stamps agent_done;
#   2. starts the project's dev server (npm run dev, preview fallback) and
#      opens Safari on it, paints the UNIFORM 8-test acceptance battery
#      (performed on camera; Return-gated);
#   3. stops the recording, stamps run_end, prints proof + export command
#      (via end-run.sh — ONE wrap path).
# Run it in a NEW Terminal window (Command+N) — Claude Code owns MAIN.
HARNESS_VERSION="1.6.25"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
SHOW_SECS="${TTA_SHOW_SECS:-20}"
tl() { printf '%s\tguest\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$HOME/tta/run-times.log"; }

printf '\033]0;wikiTaTa Test Your Agent : FINISH\007'
# idempotent: the guide can auto-fire this AND the operator can run it — only
# the first instance proceeds (a lock older than 10 min is treated as stale)
LOCK="$HOME/tta/.finish.lock"
if [ -f "$LOCK" ]; then
  AGE=$(( $(date +%s) - $(cat "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 600 ]; then
    echo ""; echo "  FINISH is already running in another window - nothing to do here."
    exit 0
  fi
fi
date +%s > "$LOCK"
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
  open -a Safari "$URL"
  tl "app_on_camera $URL"
  SHOWCASE=1
elif [ -f index.html ]; then
  echo "  no dev server found - opening index.html directly"
  open -a Safari "index.html"
  tl app_on_camera_static
  SHOWCASE=1
else
  echo "  WARNING: nothing to open (no dev/preview script, no index.html) - skipping showcase"
  tl finish_no_showcase
  SHOWCASE=0
fi

if [ "$SHOWCASE" = "1" ]; then
  # the UNIFORM acceptance battery — identical for every creation, performed
  # ON CAMERA. Single source: written to acceptance.txt; the RUN GUIDE
  # (top right) watches the stamps and renders it too, PULSING — so the
  # tests stay visible even when Safari covers this window.
  cat > "$HOME/tta/acceptance.txt" <<'TESTS'
BASIC
  T1   1 * 2 * 3 + 4 - 5        expect 5
  T2   12.5 + 87.5              expect 100
  T3   22 / 7                   expect 3.1428571...
  T4   ( 8 + 2 ) * ( 6 - 1 )    expect 50
  T5   100 - 250                expect -150
SCIENTIFIC
  T6   sqrt(144)                expect 12
  T7   2 ^ 10                   expect 1024
  T8   sin(30 deg)              expect 0.5
TESTS
  echo ""
  printf '\033[1;36m ╔════════════════════════════════════════════════════════════╗\033[0m\n'
  printf '\033[1;36m ║   UNIFORM ACCEPTANCE TEST - perform these IN the app now    ║\033[0m\n'
  printf '\033[1;36m ╚════════════════════════════════════════════════════════════╝\033[0m\n'
  echo "   Key each one in; watch the tape record it. Same battery for"
  echo "   every creation, so runs stay comparable. (The RUN GUIDE window,"
  echo "   top right, shows this list too - follow it there.)"
  echo ""
  sed 's/^/   /' "$HOME/tta/acceptance.txt"
  echo ""
  printf '\033[1m   PRESS RETURN here when the tests are done.\033[0m\n'
  tl acceptance_tests_shown
  read -r || true
  tl acceptance_tests_done
  # keep recording a clean tail of the finished app before stopping (Todd:
  # not a 5s wrap — hold ~20s). Configurable via run.conf TTA_WRAP_HOLD.
  HOLD="${TTA_WRAP_HOLD:-20}"
  printf '\033[1;32m   final capture - recording the finished app for %ss...\033[0m\n' "$HOLD"
  tl "wrap_hold_${HOLD}s"
  sleep "$HOLD"
fi

echo ""
echo "  stopping the recording + finalizing..."
"$HOME/tta/end-run.sh"
