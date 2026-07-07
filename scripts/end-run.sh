#!/bin/bash
# end-run.sh — run when the agent is done (or the 45-min cap hits):
# stamps the end time, stops + finalizes the recording, prints the proof
# and the export command to run on the VM host.
HARNESS_VERSION="1.6.12"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
printf '%s\tguest\trun_end\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$HOME/tta/run-times.log"
pkill -INT -x screencapture 2>/dev/null
sleep 3
echo
if [ -s "$HOME/tta/recording.mov" ]; then
  ls -l "$HOME/tta/recording.mov"
  echo ">>> RECORDING STOPPED AND SAVED <<<"
else
  echo ">>> WARNING: no recording file found — report this <<<"
fi
echo
echo "Now, on the VM HOST (not in this VM):"
echo "  cd ~/tta-runs/staging && ./export-run.sh run-$RUN_ID $RUN_ID"
