# Operator Runbook — pilot run `calc-A-basic-1`
**Version 1.4** · revisions increment 1.1, 1.2, 1.3… (never a 2.x without a protocol change)

**What this is:** you operate the FIRST pilot cell — tier **A** (bare Claude, no MCP), project **Calculator**, persona **BASIC**. Total hands-on time ≈ 5 minutes of setup, then you mostly watch. Hard cap: **45 minutes**, target 15.

## Platform — read this first

- **The guest VM is a macOS VM**, and the harness uses [Tart](https://tart.run), which only runs on an **Apple Silicon Mac** ("the VM host" below — any M-series Mac with ≥16 GB free for the guest; more is better).
- **The challenge itself is platform-agnostic** — anyone can run the starter + startup instruction on any machine with Claude Code (see [CHALLENGE.md](CHALLENGE.md)). The VM harness in this runbook exists for *controlled, reproducible, instrumented* runs: fresh-snapshot isolation, in-guest recording, and a complete capture bundle.
- Running instrumented runs on Intel Macs, Linux, or Windows needs a different VM harness (UTM / QEMU / Hyper-V equivalents). Not provided yet — contributions welcome; the capture-bundle spec is VM-tool-independent.

**Seeing the VM's screen:** the VM window opens on the **VM host's own desktop**. Work at that desktop directly, or connect to it with **macOS Screen Sharing** — either way you're looking at the VM host's desktop and the VM window on it. Plain SSH is fine for every *command* in this runbook, but SSH alone cannot show you the VM window, and the run requires you to see and use it.

**Your persona (BASIC) — the three rules while the agent runs:**
1. Answer any question the agent asks with the shortest sensible answer. Approve permission prompts (that's normal operation, not steering).
2. NEVER suggest features, tools, designs, or approaches. Never say "try X".
3. Only speak unprompted if the agent has been idle with no question for ~60 seconds — then say exactly: `continue`.

---

## Setup — one command

**1.** Open a Terminal on the VM host's desktop (directly or via Screen Sharing) and run:

```bash
curl -fsSL https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/run-pilot.sh | bash
```

The script narrates exactly what it is doing at every step (live progress bar): it checks the VM host, downloads the starter + capture scripts, clones the golden image `tta-base-a` into a fresh disposable VM `run-calc-A-basic-1`, boots it **in the background** (your terminal stays free; the VM window opens on the desktop — if you don't see it, check Mission Control, it may land on another Space), waits for it to come up, and pushes the starter into it.

✅ Expect: seven ✓ steps ending in a boxed **READY** checklist. That checklist is steps 2–4 below, printed with everything filled in.

*(Ran it over plain SSH instead? It stages everything, then tells you the single `tart run` command to issue from a desktop Terminal and how to `--resume`. Prefer to see every raw command? Appendix A has the full manual sequence.)*

---

## The run (inside the VM window)

**2.** In the VM window: open **Terminal** (⌘-Space, type Terminal) and paste the one-block setup the READY checklist printed (unpacks the challenge to `~/challenge` and starts the 30-second stills loop).

✅ Expect: silence — the stills loop is snapping a PNG every 30s in the background.

**3.** Still in the VM: **QuickTime Player** → File → **New Screen Recording** → record the **entire screen**. Leave it recording. (When you stop it at the end, save as `recording.mov` to the Desktop.)

**4.** In the VM Terminal:
```bash
cd ~/challenge/calculator && claude
```
✅ Expect: Claude Code starts. (No login prompt — the golden image is pre-authed.)

**5.** Paste this **exactly**, as one message — this is the only steering you give. **The clock starts at this paste.**

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

**6.** Follow the BASIC persona rules (top of this page). Jot a one-line note (with rough time) for anything you type — that's the operator log.

**7.** The run ends when the agent declares done, **or at 45 minutes** — whichever comes first. Then in the VM: stop the QuickTime recording, save as `recording.mov` **to the Desktop**, and quit QuickTime.

---

## Export & watch

**8.** In a Terminal on the VM host:
```bash
cd ~/tta-runs/staging && ./export-run.sh run-calc-A-basic-1 calc-A-basic-1
open ~/tta-runs/calc-A-basic-1/index.html
```
✅ Expect: the bundle lists (repo, transcripts, stills, recording), and the **Run Viewer** opens — a flip-book of the stills with a [−  5.0 s/frame  +] speed control, arrow keys to step, and the full video below.

**9.** Report where the bundle is (`~/tta-runs/calc-A-basic-1` on the VM host) — token accounting and the run-report skeleton are generated from it with `scripts/analyze-run.mjs <bundle-dir>`. Don't delete the VM; leave it stopped for inspection (`tart stop run-calc-A-basic-1` if it's still running).

**Something broke?** Don't improvise — note where, leave everything as-is, and report. A voided pilot that teaches us something IS the pilot doing its job.

---

## Appendix A — manual setup (what run-pilot.sh does, as raw commands)

All on the VM host; the `tart run` line must be issued from a Terminal on its desktop.

```bash
mkdir -p ~/tta-runs/staging && cd ~/tta-runs/staging
curl -fsSLO https://github.com/catMarvin/wikitata-test-your-agent/releases/latest/download/calculator-starter.zip
curl -fsSLO https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/capture-stills.sh
curl -fsSLO https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/export-run.sh
chmod +x capture-stills.sh export-run.sh
tart clone tta-base-a run-calc-A-basic-1
nohup tart run run-calc-A-basic-1 >/dev/null 2>&1 &     # backgrounded — the terminal stays free
IP=$(tart ip run-calc-A-basic-1)                        # retry until it prints an IP (boot takes a bit)
scp -o StrictHostKeyChecking=no calculator-starter.zip capture-stills.sh admin@$IP:
```

Then continue at step 2 ("The run"). In-VM one-block setup for step 2:

```bash
unzip -q ~/calculator-starter.zip -d ~/challenge && mkdir -p ~/tta && \
mv ~/capture-stills.sh ~/tta/ && chmod +x ~/tta/capture-stills.sh && \
RUN_ID=calc-A-basic-1 INTERVAL=30 ~/tta/capture-stills.sh > ~/tta/stills.log 2>&1 &
```

Health checks any time: `tart list` (state=running) · `tart ip run-calc-A-basic-1` (prints an IP once booted).

---
*Revisions: 1.0 initial · 1.1 step-3 opens a new tab (`tart run` holds its terminal) · 1.2 ssh-first flow + state-based expectations + health checks · 1.3 display-path split · 1.4 generic operator rewrite: platform section (macOS guest VM on an Apple Silicon host — stated explicitly), the VM-host desktop / Screen Sharing as the ONLY display path (remote-display alternative removed), one-command `run-pilot.sh` setup with backgrounded boot, host-specific names and paths removed.*
