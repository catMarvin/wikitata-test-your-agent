#!/bin/bash
# run-pilot.sh — one-command pilot-run launcher for the instrumented harness.
#
# WHAT THIS DOES (in order, narrating each step):
#   1. Checks the VM host has what it needs (tart + the golden image).
#   2. Downloads the starter + capture scripts into a staging folder.
#   3. Clones the golden image into a fresh, disposable run VM.
#   4. Boots the run VM in the background (its window opens on the VM host's
#      desktop — watch it there, or through macOS Screen Sharing).
#   5. Waits for the VM to get an IP and accept SSH.
#   6. Pushes the starter + stills script into the VM.
#   7. Prints the short operator checklist for the run itself.
#
# WHERE TO RUN IT: in a Terminal on the VM host. The VM's screen appears on
# the VM host's own desktop, so run this from a Terminal *on that desktop*
# (directly, or inside a macOS Screen Sharing session). If you run it over
# plain SSH instead, it stages everything and then tells you the one command
# to run from a desktop Terminal — plain SSH has no desktop to open a VM
# window on.
#
# PLATFORM: the harness runs macOS guest VMs via Tart, which requires an
# APPLE SILICON Mac as the VM host. See the runbook's platform section.
#
# USAGE:
#   ./run-pilot.sh                                # pilot defaults (calculator, tier A)
#   ./run-pilot.sh <project> <golden-image> <run-id>
#   ./run-pilot.sh --resume                       # continue after booting the VM yourself
set -euo pipefail

PROJECT="${1:-calculator}"
GOLDEN="${2:-tta-base-a}"
RUN_ID="${3:-calc-A-basic-1}"
RESUME=0
[ "${1:-}" = "--resume" ] && { RESUME=1; PROJECT="${2:-calculator}"; GOLDEN="${3:-tta-base-a}"; RUN_ID="${4:-calc-A-basic-1}"; }
VM="run-${RUN_ID}"
STAGE="$HOME/tta-runs/staging"
RAW="https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main"
REL="https://github.com/catMarvin/wikitata-test-your-agent/releases/latest/download"
STEPS=7

# ---- two-line live status: progress bar + current step -----------------------
IS_TTY=0; [ -t 1 ] && IS_TTY=1
CUR=0
bar() {
  local filled=$1 total=$2 out="" i
  for ((i=1;i<=total;i++)); do [ "$i" -le "$filled" ] && out+="■" || out+="□"; done
  printf '%s' "$out"
}
step() { # step <n> "<label>"
  CUR=$1
  if [ "$IS_TTY" = 1 ]; then
    printf '\r\033[2K[%s] step %d/%d\n\033[2K  ▸ %s' "$(bar "$CUR" "$STEPS")" "$CUR" "$STEPS" "$2"
    printf '\033[1A\r'
  else
    printf '[%d/%d] %s\n' "$CUR" "$STEPS" "$2"
  fi
}
ok() { [ "$IS_TTY" = 1 ] && printf '\n\033[2K  ✓ %s\n' "$1" || printf '  ✓ %s\n' "$1"; }
die() { printf '\n✗ %s\n' "$1" >&2; exit 1; }

# ---- 1. preflight -------------------------------------------------------------
step 1 "Checking the VM host (tart installed, golden image '${GOLDEN}' present)..."
command -v tart >/dev/null || die "tart is not installed on this VM host. Install: brew install cirruslabs/cli/tart  (requires an Apple Silicon Mac)"
tart list 2>/dev/null | awk '{print $2}' | grep -qx "${GOLDEN}" || die "golden image '${GOLDEN}' not found — build it first (runbook: golden-image section)"
ok "VM host ready (tart $(tart --version 2>/dev/null || echo '?'), golden '${GOLDEN}' present)"

# ---- 2. stage downloads --------------------------------------------------------
step 2 "Downloading the ${PROJECT} starter + capture scripts into ${STAGE}..."
mkdir -p "${STAGE}"; cd "${STAGE}"
curl -fsSLO "$REL/${PROJECT}-starter.zip"
curl -fsSLO "$RAW/scripts/capture-stills.sh"
curl -fsSLO "$RAW/scripts/export-run.sh"
chmod +x capture-stills.sh export-run.sh
ok "staged: ${PROJECT}-starter.zip, capture-stills.sh, export-run.sh"

# ---- 3. clone golden → run VM ---------------------------------------------------
step 3 "Creating a fresh disposable run VM '${VM}' from '${GOLDEN}' (copy-on-write clone)..."
if tart list 2>/dev/null | awk '{print $2}' | grep -qx "${VM}"; then
  ok "run VM '${VM}' already exists — reusing it (delete with 'tart delete ${VM}' for a truly fresh run)"
else
  tart clone "${GOLDEN}" "${VM}"
  ok "cloned '${GOLDEN}' → '${VM}' (instant — real disk writes happen as the VM boots)"
fi

# ---- 4. boot (needs the VM host's desktop) --------------------------------------
step 4 "Booting '${VM}' — its window opens on the VM host's desktop..."
VM_STATE=$(tart list 2>/dev/null | awk -v vm="${VM}" '$2==vm {print $NF}')
if [ "$VM_STATE" = "running" ]; then
  ok "'${VM}' is already running"
elif [ "$(launchctl managername 2>/dev/null)" = "Aqua" ]; then
  nohup tart run "${VM}" >/dev/null 2>&1 &
  ok "boot started in the background (this terminal stays free). If no window appears, check Mission Control — it may open on another Space."
else
  printf '\n\n'
  echo "── ACTION NEEDED ────────────────────────────────────────────────────────"
  echo "This terminal is a plain SSH session — it has no desktop to open the VM"
  echo "window on. Open a Terminal on the VM host's DESKTOP (directly or via"
  echo "macOS Screen Sharing) and run:"
  echo
  echo "    nohup tart run ${VM} >/dev/null 2>&1 &"
  echo
  echo "Then, from any terminal, continue with:"
  echo
  echo "    ${STAGE}/run-pilot.sh --resume ${PROJECT} ${GOLDEN} ${RUN_ID}"
  echo "─────────────────────────────────────────────────────────────────────────"
  # keep a copy of this script in staging so --resume works from anywhere
  curl -fsSL "$RAW/scripts/run-pilot.sh" -o "${STAGE}/run-pilot.sh" 2>/dev/null && chmod +x "${STAGE}/run-pilot.sh" || true
  exit 0
fi

# ---- 5. wait for IP + SSH --------------------------------------------------------
step 5 "Waiting for '${VM}' to finish booting (IP address, then SSH)..."
IP=""
for _ in $(seq 1 60); do IP=$(tart ip "${VM}" 2>/dev/null) && [ -n "${IP}" ] && break; sleep 3; done
[ -n "${IP}" ] || die "no IP after 3 minutes — is the VM window up and booted to the desktop?"
for _ in $(seq 1 40); do
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o BatchMode=yes "admin@${IP}" true 2>/dev/null && break
  sleep 3
done
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o BatchMode=yes "admin@${IP}" true 2>/dev/null \
  || die "VM has IP ${IP} but SSH isn't accepting the host's key. (Guest user is 'admin' — the golden image should carry the host's key; see runbook.)"
ok "VM is up at ${IP} and accepting SSH"

# ---- 6. push the starter + stills script into the guest ---------------------------
step 6 "Copying the starter and stills script into the VM..."
scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${PROJECT}-starter.zip" capture-stills.sh "admin@${IP}:" \
  || die "copy failed"
ok "copied ${PROJECT}-starter.zip + capture-stills.sh into the VM's home folder"

# ---- 7. operator handoff -----------------------------------------------------------
step 7 "Setup complete — the rest happens inside the VM window."
printf '\n\n'
cat <<EOF
══════════════════════════════════════════════════════════════════════════════
 READY: '${VM}' is booted and staged. The rest happens INSIDE THE VM.

 0. FIND THE VM WINDOW: it is a separate window on this desktop named
    '${VM}' showing a whole macOS desktop. Not seeing it? Open
    Mission Control (F3, or swipe up with 3 fingers) — it may be on
    another Space. CLICK INSIDE that window: from then on your keyboard
    and mouse control the VM (the Mac-in-a-window), not this machine.

 1. Inside the VM: press Cmd-Space, type Terminal, press Return (this
    opens the VM's OWN Terminal). Paste this ONE block into it
    (unpacks the challenge + starts the 30s stills loop):

    unzip -q ~/${PROJECT}-starter.zip -d ~/challenge && mkdir -p ~/tta && \\
    mv ~/capture-stills.sh ~/tta/ && chmod +x ~/tta/capture-stills.sh && \\
    RUN_ID=${RUN_ID} INTERVAL=30 ~/tta/capture-stills.sh > ~/tta/stills.log 2>&1 &

 2. Still inside the VM: Cmd-Space, type QuickTime, Return →
    File → New Screen Recording → record the ENTIRE screen. Leave it running.
    (At the end: stop, save as recording.mov to the VM's Desktop.)

 3. Back in the VM's Terminal:   cd ~/challenge/${PROJECT} && claude
    Paste the startup instruction from the runbook VERBATIM.
    ⏱  The clock starts at that paste. Persona rules apply from here.

 AFTER THE RUN (agent done, or 45-min cap):
    stop + save the recording, then back on the VM host:
       cd ${STAGE} && ./export-run.sh ${VM} ${RUN_ID}
══════════════════════════════════════════════════════════════════════════════
EOF
