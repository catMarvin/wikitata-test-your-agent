#!/bin/bash
# run-guide.sh — operator guide window; run INSIDE the guest VM in its own
# Terminal window (the runbook opens it that way via osascript).
#
# WHAT IT DOES:
#   1. Downloads the project's official startup instruction (the ONLY steering
#      the operator gives the agent) from instructions/<project>.txt.
#   2. Puts that instruction ON THE CLIPBOARD (pbcopy) — the operator just
#      presses Command+V inside Claude Code.
#   3. Shows a formatted step-by-step guide for the run, and stays on screen.
#
# Usage: run-guide.sh [project] [run-id]     (defaults: calculator, calc-A-basic-1)
HARNESS_VERSION="1.6.2"
SELF_SHA=$(shasum "$0" 2>/dev/null | cut -c1-8)
PROJECT="${1:-calculator}"
RUN_ID="${2:-calc-A-basic-1}"
RAW="https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main"
INSTR="$HOME/tta/startup-instruction.txt"

mkdir -p "$HOME/tta"
if ! curl -fsSL "$RAW/instructions/${PROJECT}.txt" -o "$INSTR"; then
  echo "FAIL: could not download the startup instruction for '${PROJECT}' — report this."
  exit 1
fi
pbcopy < "$INSTR" || { echo "FAIL: could not load the clipboard — report this."; exit 1; }
printf '%s\tguest\tguide_opened_clipboard_loaded\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$HOME/tta/run-times.log"

clear
cat <<GUIDE

 =====================================================================
   YOUR NEXT MOVES — THE RUN STARTS FROM THIS GUIDE
 =====================================================================

   The startup instruction is ALREADY ON THE CLIPBOARD of this Mac.
   (It is the only steering you ever give the agent.)

   STEP 1 — LAUNCH THE AGENT
     Go back to the MAIN Terminal window (the one you ran setup in)
     and type this, then press Return:

       tl claude_launch; cd ~/challenge/${PROJECT} && claude

     Claude Code starts. No login is needed.

   STEP 2 — PASTE THE INSTRUCTION        <<< THE CLOCK STARTS HERE
     Click into Claude Code, press  Command+V  (or Edit > Paste),
     then press Return.

     The moment you press Return, the run is LIVE and timed.

   WHILE THE RUN IS LIVE — your persona is BASIC:
     - Agent asks a question?  Shortest sensible answer.
     - Permission prompt?      Approve it. That is normal use.
     - NEVER suggest features, tools, designs, or approaches.
     - Agent idle ~60s with no question?  Type exactly:  continue
     - Jot down anything you type, with a rough time.

   THE RUN ENDS when the agent declares done — or at 45 minutes,
   whichever comes first. Then:
     1. Stop the recording (see the recording window's instructions).
     2. Run the run-end line from the launcher checklist.

   Clipboard got overwritten? Reload it any time with:
     pbcopy < ~/tta/startup-instruction.txt

 =====================================================================
   Leave this window open for reference during the run.
   harness v${HARNESS_VERSION} (${SELF_SHA}) · run-id ${RUN_ID}
 =====================================================================

GUIDE
