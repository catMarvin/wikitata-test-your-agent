#!/bin/bash
# run-pilot.sh — one-command pilot-run launcher for the instrumented harness.
#
# WHAT THIS DOES (narrating each step, timestamping each to run-times.log):
#   1. Checks the VM host has what it needs (tart + the golden image).
#   2. Stages the export script and starts the run's timing log.
#   3. Clones the golden image into a fresh, disposable run VM.
#   4. Prints the in-VM checklist, then BECOMES the VM: the script's last act
#      is launching the VM in THIS terminal — its window opens, and this
#      terminal stays attached to the VM for its whole life (that is normal;
#      when the VM later shuts down, your prompt returns).
#
# No second terminal, no tabs: the guest downloads its own starter, so nothing
# has to run on the host after boot.
#
# WHERE TO RUN IT: a Terminal on the VM host's desktop (directly or inside a
# macOS Screen Sharing session). Over plain SSH it prepares everything and
# prints the one command to run from a desktop Terminal (a VM window cannot
# open from a plain SSH session).
#
# PLATFORM: macOS guest VMs via Tart — requires an APPLE SILICON Mac as the
# VM host. See the runbook's platform section.
#
# USAGE:
#   ./run-pilot.sh                                # pilot defaults (calculator, tier A)
#   ./run-pilot.sh <project> <golden-image> <run-id>
set -euo pipefail

PROJECT="${1:-calculator}"
GOLDEN="${2:-tta-base-a}"
RUN_ID="${3:-calc-A-basic-1}"
VM="run-${RUN_ID}"
STAGE="$HOME/tta-runs/staging"
OUT="$HOME/tta-runs/${RUN_ID}"
RAW="https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main"
REL="https://github.com/catMarvin/wikitata-test-your-agent/releases/latest/download"
STEPS=4

IS_TTY=0; [ -t 1 ] && IS_TTY=1
bar() {
  local filled=$1 total=$2 out="" i
  for ((i=1;i<=total;i++)); do [ "$i" -le "$filled" ] && out+="#" || out+="-"; done
  printf '%s' "$out"
}
step() {
  if [ "$IS_TTY" = 1 ]; then
    printf '\r\033[2K[%s] step %d/%d\n\033[2K  > %s' "$(bar "$1" "$STEPS")" "$1" "$STEPS" "$2"
    printf '\033[1A\r'
  else
    printf '[%d/%d] %s\n' "$1" "$STEPS" "$2"
  fi
}
ok() { [ "$IS_TTY" = 1 ] && printf '\n\033[2K  OK %s\n' "$1" || printf '  OK %s\n' "$1"; }
die() { printf '\nFAIL %s\n' "$1" >&2; exit 1; }
tlog() { # tlog <event> — timestamped line into the run's host timing log
  mkdir -p "${OUT}"
  printf '%s\thost\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "${OUT}/run-times.log"
}

# ---- 1. preflight ----------------------------------------------------------
step 1 "Checking the VM host (tart installed, golden image '${GOLDEN}' present)..."
tlog "script_start project=${PROJECT} golden=${GOLDEN}"
command -v tart >/dev/null || die "tart is not installed on this VM host. Install: brew install cirruslabs/cli/tart  (requires an Apple Silicon Mac)"
tart list 2>/dev/null | awk '{print $2}' | grep -qx "${GOLDEN}" || die "golden image '${GOLDEN}' not found — build it first (runbook: golden-image section)"
ok "VM host ready (tart $(tart --version 2>/dev/null || echo '?'), golden '${GOLDEN}' present)"

# ---- 2. stage host-side tooling ---------------------------------------------
step 2 "Staging the export script into ${STAGE}..."
mkdir -p "${STAGE}"; cd "${STAGE}"
curl -fsSLO "$RAW/scripts/export-run.sh" && chmod +x export-run.sh
tlog staging_done
ok "staged export-run.sh (the guest downloads its own starter — nothing else needed host-side)"

# ---- 3. clone golden -> run VM ------------------------------------------------
step 3 "Creating a fresh disposable run VM '${VM}' from '${GOLDEN}' (copy-on-write clone)..."
if tart list 2>/dev/null | awk '{print $2}' | grep -qx "${VM}"; then
  ok "run VM '${VM}' already exists — reusing it (delete with 'tart delete ${VM}' for a truly fresh run)"
else
  tart clone "${GOLDEN}" "${VM}"
  ok "cloned '${GOLDEN}' -> '${VM}' (instant — real disk writes happen as the VM boots)"
fi
tlog clone_done

# ---- 4. handoff + become the VM ------------------------------------------------
step 4 "Handing off: this terminal now becomes the VM."
printf '\n\n'
cat <<EOF
==============================================================================
 NEXT: the VM window is about to open (this terminal stays attached to the
 VM — normal; your prompt returns when the VM shuts down). Everything below
 happens INSIDE that window: click into it — from then on your keyboard and
 mouse control the guest Mac.

 1. Inside the VM: Cmd-Space, type Terminal, Return. Paste this ONE block
    (downloads + unpacks the challenge, starts the stills loop + timing log):

    echo admin | sudo -S scutil --set HostName wikiTaTa-TestYourAgent-VirtualMacTest 2>/dev/null; \\
    mkdir -p ~/tta ~/challenge && cd ~ && \\
    tl(){ printf '%s\\tguest\\t%s\\n' "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" "\$1" >> ~/tta/run-times.log; } && \\
    tl guest_setup_start && \\
    curl -fsSLO ${REL}/${PROJECT}-starter.zip && \\
    unzip -q ~/${PROJECT}-starter.zip -d ~/challenge && tl starter_unpacked && \\
    curl -fsSL ${RAW}/scripts/capture-stills.sh -o ~/tta/capture-stills.sh && chmod +x ~/tta/capture-stills.sh && \\
    { RUN_ID=${RUN_ID} INTERVAL=30 ~/tta/capture-stills.sh > ~/tta/stills.log 2>&1 & } && \\
    { osascript -e 'tell application "Finder" to set db to bounds of window of desktop' -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' -e 'tell application "Terminal" to set font size of selected tab of front window to 16' -e 'tell application "Terminal" to set bounds of front window to {0, 25, sw * 3 div 5, sh - 80}' >/dev/null 2>&1 || true; } && \\
    tl stills_started && echo READY

 2. Start the FULL-SCREEN video recording (REQUIRED evidence for
    instrumented runs). This ONE line opens a dedicated recording window
    with a live big-digit elapsed clock — clock ticking = recording:

      curl -fsSL ${RAW}/scripts/record-screen.sh -o ~/tta/record-screen.sh && chmod +x ~/tta/record-screen.sh && osascript -e 'tell application "Terminal" to do script "~/tta/record-screen.sh"' && osascript -e 'tell application "Finder" to set db to bounds of window of desktop' -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' -e 'tell application "Terminal" to set font size of selected tab of front window to 16' -e 'tell application "Terminal" to set bounds of front window to {sw * 3 div 5, sh * 11 div 20, sw, sh - 80}' >/dev/null 2>&1 || true; sleep 3; pgrep -x screencapture >/dev/null && echo ">>> YES: RECORDING IS LIVE — continue to the next step <<<" || echo ">>> NO: NOT RECORDING — STOP HERE. Approve the Screen Recording permission (password: admin), then run this step again. Do NOT continue until this says YES. <<<"

    The line VERIFIES ITSELF: it always ends by printing YES (continue)
    or NO (stop, approve the permission, paste the same line again).
    DO NOT continue on NO. Re-check any time later with:

      pgrep -x screencapture >/dev/null && echo YES-RECORDING || echo NOT-RECORDING

 3. Open the RUN GUIDE window — it loads the startup instruction onto
    the clipboard and walks you through launch + paste + persona rules:

      curl -fsSL ${RAW}/scripts/run-guide.sh -o ~/tta/run-guide.sh && chmod +x ~/tta/run-guide.sh && osascript -e 'tell application "Terminal" to do script "~/tta/run-guide.sh ${PROJECT} ${RUN_ID}"' && osascript -e 'tell application "Finder" to set db to bounds of window of desktop' -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' -e 'tell application "Terminal" to set font size of selected tab of front window to 16' -e 'tell application "Terminal" to set bounds of front window to {sw * 3 div 5, 25, sw, sh * 11 div 20}' >/dev/null 2>&1 || true

    Follow its STEP 1 (launch claude) and STEP 2 (Command+V the
    instruction). The run clock starts at that paste.

 AFTER THE RUN (agent done, or 45-min cap): in the VM's main Terminal:
    tl run_end 2>/dev/null; pkill -INT -x screencapture; sleep 3; ls -l ~/tta/recording.mov
 (stops + finalizes — expect a large file size; the recording window's
 banner disappearing is your visual confirmation), then on the VM host:
    cd ${STAGE} && ./export-run.sh ${VM} ${RUN_ID}
==============================================================================
EOF

if [ "$(launchctl managername 2>/dev/null)" = "Aqua" ]; then
  tlog vm_boot_exec
  exec tart run "${VM}"
else
  echo ""
  echo "This is a plain SSH session — a VM window cannot open here."
  echo "From a Terminal on the VM host's DESKTOP (directly or via macOS"
  echo "Screen Sharing), run:"
  echo ""
  echo "    tart run ${VM}"
  echo ""
  echo "and continue with the numbered steps above."
  tlog vm_boot_deferred_ssh
fi
