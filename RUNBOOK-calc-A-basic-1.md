# Operator Runbook — pilot run `calc-A-basic-1`
**Version 1.2** · revisions increment 1.1, 1.2, 1.3… (never a 2.x without a protocol change)

**What this is:** you operate the FIRST pilot cell — tier **A** (bare Claude, no MCP), project **Calculator**, persona **BASIC**. Total hands-on time ≈ 5 minutes of setup, then you mostly watch. Hard cap: **45 minutes**, target 15.

**Your persona (BASIC) — the three rules while the agent runs:**
1. Answer any question the agent asks with the shortest sensible answer. Approve permission prompts (that's normal operation, not steering).
2. NEVER suggest features, tools, designs, or approaches. Never say "try X".
3. Only speak unprompted if the agent has been idle with no question for ~60 seconds — then say exactly: `continue`.

---

## Setup (on the mini)

**1.** SSH into the mini from your Mac (`ssh m4`) — the VM's display will come to you over VNC in step 2, so you don't need the mini's own desktop.

**2.** In that SSH session, stage the run:
```bash
mkdir -p ~/tta-runs/staging && cd ~/tta-runs/staging
curl -fsSLO https://github.com/catMarvin/wikitata-test-your-agent/releases/latest/download/calculator-starter.zip
curl -fsSLO https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/capture-stills.sh
curl -fsSLO https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/export-run.sh
chmod +x capture-stills.sh export-run.sh
tart clone tta-base-a run-calc-A-basic-1
tart run run-calc-A-basic-1 --vnc
```
✅ Expect, in order: the clone command returns (copy-on-write, not a real copy — disk-usage growth afterward is normal VM boot writes), then a `vnc://…` URL prints. **Open that URL from YOUR Mac** (paste into Safari, or Finder ⌘K) — the VM's screen appears in a window and lands on a logged-in desktop (`admin`). **`tart run` keeps holding this terminal while the VM lives — that's normal.** Health checks any time, from another tab: `tart list` (state=running) and `tart ip run-calc-A-basic-1` (prints an IP once booted).

**3.** Open a **second SSH tab** (⌘T, `ssh m4` — the first tab stays attached to the VM) and push the starter + capture script into the guest:
```bash
cd ~/tta-runs/staging
```
```bash
IP=$(tart ip run-calc-A-basic-1)
scp -o StrictHostKeyChecking=no calculator-starter.zip capture-stills.sh admin@$IP:
```
✅ Expect: two files copy without a password prompt.

**4.** Click into the **VNC window** (the VM's screen), open **Terminal** there (⌘-Space, type Terminal), and run:
```bash
unzip -q ~/calculator-starter.zip -d ~/challenge && mkdir -p ~/tta
mv ~/capture-stills.sh ~/tta/ && chmod +x ~/tta/capture-stills.sh
RUN_ID=calc-A-basic-1 INTERVAL=30 ~/tta/capture-stills.sh > ~/tta/stills.log 2>&1 &
```
✅ Expect: silence (the stills loop is now snapping a PNG every 30s in the background).

**5.** Still in the VM: open **QuickTime Player** → File → **New Screen Recording** → record the **entire screen**. Leave it recording. (When you stop it at the end, save as `recording.mov` to the Desktop.)

---

## The run

**6.** In the VM Terminal:
```bash
cd ~/challenge/calculator && claude
```
✅ Expect: Claude Code starts. (No login prompt — the image is pre-authed via its keychain.)

**7.** Paste this **exactly**, as one message — this is the only steering you give. **The clock starts at this paste.**

> You are starting a new project. The complete specification is in PROJECT-BRIEF.md in this repository.
>
> Build the **Pocket Scientific Calculator** exactly as specified, as 4 parallel work streams (lanes A–D in the brief).
>
> Before any code: design the implementation of the entire project — including how you will execute and coordinate the 4 work streams — **optimized for the coordination capabilities available to you.** Then execute that design.
>
> Requirements:
> 1. All 4 lanes' scope must ship. All modules must integrate cleanly — no merge conflicts, no duplicate or competing components, no broken imports.
> 2. Design the app's visual appearance **from scratch**. No reference designs exist; visual quality will be judged.
> 3. Target: under 15 minutes total wall-clock. Speed matters, but a broken build scores zero.
> 4. Keep a step-by-step record of everything you do: decisions, agent dispatches, file writes, integration steps.
> 5. Done = the build succeeds and the app runs with every specified feature working.

**8.** Follow the BASIC persona rules (top of this page). Jot a one-line note (with rough time) for anything you type — that's the operator log.

**9.** The run ends when the agent declares done, **or at 45 minutes** — whichever comes first. Then in the VM: stop the QuickTime recording, save as `recording.mov` **to the Desktop**, and quit QuickTime.

---

## Export & watch

**10.** Back in the **mini Terminal**:
```bash
cd ~/tta-runs/staging && ./export-run.sh run-calc-A-basic-1 calc-A-basic-1
open ~/tta-runs/calc-A-basic-1/index.html
```
✅ Expect: the bundle lists (repo, transcripts, stills, recording), and the **Run Viewer** opens — flip-book of the stills with a [−  5.0 s/frame  +] speed control, arrow keys to step, and the full video below.

**11.** Tell Claude (any wikiTaTa chat): *"pilot bundle is at ~/tta-runs/calc-A-basic-1 on the mini"* — analysis, token accounting, and the run-report card happen from there. Don't delete the VM; leave it stopped for inspection (`tart stop run-calc-A-basic-1` if it's still running).

**Something broke?** Don't improvise — note where, leave everything as-is, and report. A voided pilot that teaches us something IS the pilot doing its job.

---
*Revisions: 1.0 initial · 1.1 step-3 opens a new tab (`tart run` holds its terminal) · 1.2 ssh-first flow with `--vnc` display + state-based expectations + health checks.*
