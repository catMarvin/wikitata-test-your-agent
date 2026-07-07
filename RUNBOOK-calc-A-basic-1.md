# Operator Runbook — pilot run `calc-A-basic-1`
**Version 1.5** · revisions increment 1.1, 1.2, 1.3… (never a 2.x without a protocol change)

You are about to operate one instrumented challenge run: tier **A** (bare Claude, no MCP), project **Calculator**, persona **BASIC**. Hands-on setup is a few minutes; then you mostly watch. The run itself ends when the agent finishes or at **45 minutes**, whichever comes first.

This guide assumes nothing. Every step tells you what to do, exactly how to do it, and what you should see before moving on. If what you see doesn't match, stop and check the Troubleshooting section at the bottom — don't improvise.

---

## Words used in this guide

| Word | Means |
|---|---|
| **VM host** | The physical Apple Silicon Mac the run happens on. |
| **VM** | A complete second Mac running *inside a window* on the VM host ("virtual machine"). |
| **Inside the VM** | You clicked into the VM's window, so your keyboard and mouse now control that inner Mac — not the real one. |
| **Terminal** | The app where you type commands. The VM host has one; the VM has its *own separate one*. This guide always says which. |

## What you need before starting

1. **An Apple Silicon Mac as the VM host** (any M-series). The guest VM is macOS; the harness tool ([Tart](https://tart.run)) does not run on Intel Macs, Linux, or Windows — see [README → Platform notes](README.md).
2. **The golden image `tta-base-a` already built on that Mac.** (One-time build; if `tart list` doesn't show it, do the golden-image build first — not this document.)
3. **A way to see the VM host's screen:** sit at it, or connect with macOS Screen Sharing. Either way you are looking at its desktop. *Plain SSH is not enough* — the VM opens as a window on the desktop, and you must see and use that window.

## Your persona: BASIC — the rules while the agent runs

You are playing "a regular user who pasted an instruction and waits." Three rules plus a notebook, no exceptions:

1. If the agent asks a question, answer with the **shortest sensible answer**. Approving permission prompts is fine — that's normal use, not steering.
2. **Never** suggest a feature, tool, design, or approach. Never say "try X". Never point out a problem.
3. Speak unprompted **only** if the agent has sat idle, with no question pending, for about 60 seconds — then type exactly: `continue`
4. Keep a scrap note: anything you type, and roughly when. That note is the operator log and ships with the results.

---

## PART 1 — Start everything (on the VM host)

### Step 1. Open a Terminal on the VM host's desktop

At the VM host (or in your Screen Sharing view of it): click the desktop, press **⌘-space** (hold the command key, tap the space bar), type `Terminal`, press **Return**.

✅ **You should now see:** a window with a text prompt ending in `$` or `%`, waiting for you to type.

### Step 2. Run the launcher

Copy this whole line, paste it at the prompt, press **Return**:

```bash
curl -fsSL https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/run-pilot.sh | bash
```

The launcher narrates itself: it checks the VM host, stages the export tool, creates a fresh disposable VM, prints the checklist you'll use in Part 2, and then **turns this terminal into the VM** — a new window opens containing an entire second Mac.

✅ **You should now see:** four `OK` lines, a boxed checklist (a filled-in copy of Part 2 below — leave it on screen), and then a **new window** with a macOS desktop booting inside it. Your terminal stops accepting input: it is now attached to the VM for the whole run. That is normal — you never need this terminal again until Part 4, and your prompt comes back when the VM shuts down.

⏳ First boot can take a minute or two. Wait until the inner Mac shows a normal desktop (menu bar, dock, wallpaper).

---

## PART 2 — Prepare the inside of the VM

⚠️ **First: click once inside the VM's window.** From that click on, everything you type goes to the inner Mac. (To get your mouse and keyboard back to the real Mac later, just click outside the window.)

### Step 3. Open the VM's own Terminal

Inside the VM: press **⌘-space**, type `Terminal`, press **Return**.

✅ **You should now see:** a second Terminal — this one belongs to the inner Mac. Everything in Part 2 happens here.

### Step 4. Set up the challenge + start the automatic stills camera

The boxed checklist from Step 2 printed a paste-block. Copy that whole block (all lines together) into the VM's Terminal and press **Return**. It downloads the challenge, unpacks it, and starts a camera that snaps the screen every 30 seconds — plus a timing log.

✅ **You should now see:** the word `READY` printed, then the prompt back.
❌ If you see `command not found` or an error mentioning `curl` or `unzip`: stop, note the exact text, and report it.

### Step 5. Start the screen recording — MANUAL. This is the step people miss.

The stills camera from Step 4 is automatic; the video recording starts with one more paste. *(Required for instrumented runs — it is a mandatory evidence witness. Casual challengers outside the harness: recommended, not required — see CAPTURE.md.)*

1. In the VM's Terminal, paste this **one line** and press **Return** — it opens a **dedicated recording window** with a live big-digit elapsed clock, recording the **entire screen** (no QuickTime, no clicking, nothing to aim):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/record-screen.sh -o ~/tta/record-screen.sh && chmod +x ~/tta/record-screen.sh && osascript -e 'tell application "Terminal" to do script "~/tta/record-screen.sh"' && osascript -e 'tell application "Finder" to set db to bounds of window of desktop' -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' -e 'tell application "Terminal" to set bounds of front window to {sw * 3 div 5, sh * 11 div 20, sw, sh}' >/dev/null 2>&1 || true
   ```
2. **First time only:** macOS may ask Screen Recording permission for Terminal — click **Allow** (System Settings opens: switch **Terminal** on, enter the VM password `admin`, let Terminal quit & reopen), then paste the line again.
3. **Verify it, don't trust it** — back in your main Terminal window, paste:
   ```bash
   pgrep -x screencapture >/dev/null && echo ">>> YES: SCREEN IS BEING RECORDED <<<" || echo ">>> NO: NOT RECORDING — redo the recording step <<<"
   ```

✅ **You should now see:** a second Terminal window showing `>>> SCREEN RECORDING IN PROGRESS <<<` with a **big ASCII clock counting up every second**, and the verify line answering `YES`. Clock ticking = recording; clock gone (`NO LONGER BEING RECORDED`) = not.
🚫 **Do not proceed to Part 3 until the verify line says YES.** A run without the recording is missing a required piece of evidence.
📺 The window stays visible the entire run — while it shows the banner, you're recording; when it drops back to a prompt, you're not. Run the verify line any time you're unsure.

---

## PART 3 — The run itself

### Step 6. Open the run-guide window (it loads your clipboard)

In the VM's Terminal, paste this **one line** and press **Return** — it opens a guide window that puts the official startup instruction **directly onto the VM's clipboard** and shows your next moves:

```bash
curl -fsSL https://raw.githubusercontent.com/catMarvin/wikitata-test-your-agent/main/scripts/run-guide.sh -o ~/tta/run-guide.sh && chmod +x ~/tta/run-guide.sh && osascript -e 'tell application "Terminal" to do script "~/tta/run-guide.sh calculator calc-A-basic-1"' && osascript -e 'tell application "Finder" to set db to bounds of window of desktop' -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' -e 'tell application "Terminal" to set bounds of front window to {sw * 3 div 5, 25, sw, sh * 11 div 20}' >/dev/null 2>&1 || true
```

✅ **You should now see:** a guide window titled "YOUR NEXT MOVES" docked to the **top-right**, confirming the instruction is on the clipboard. The three windows now tile themselves: main Terminal left, guide top-right, recording clock bottom-right. *(First time, macOS may ask to let Terminal control Finder — that's only for window positioning; Allow or Deny, everything works either way.)*

### Step 7. Follow the guide: launch, then ⌘V — the clock starts at the paste

Per the guide's STEP 1, in the **main** VM Terminal: `tl claude_launch; cd ~/challenge/calculator && claude` → Claude Code starts, no login. Then STEP 2: click into Claude Code, press **⌘V** (or Edit → Paste), press **Return**.

The pasted text is exactly this — shown here for reference only; you never need to hand-copy it:

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

⏱ **The moment you press Return, the run has started.** Persona rules (top of this page) govern everything you do from now on. Note the time.

### Step 8. Watch. The run ends two ways

- The agent declares it is **done**, or
- **45 minutes** pass since the paste — then you stop it regardless.

---

## PART 4 — Stop, save, export

### Step 9. Stamp the end + stop the recording (inside the VM)

1. In the VM's main Terminal, paste and press **Return** — stamps the end time, stops the recorder (same as Ctrl-C in the recording window), and shows the finished file:
   ```bash
   tl run_end 2>/dev/null; pkill -INT -x screencapture; sleep 3; ls -l ~/tta/recording.mov; pgrep -x screencapture >/dev/null && echo ">>> STILL RECORDING?! report this" || echo ">>> RECORDING STOPPED AND SAVED <<<"
   ```
✅ **You should now see:** `recording.mov` listed with a large file size, and `>>> RECORDING STOPPED AND SAVED <<<`. The recording window drops back to a prompt — its banner gone is your visual confirmation.

### Step 10. Export the results bundle (on the VM host)

Click **outside** the VM window (you're back on the real Mac). Open a **new** Terminal (⌘-space → `Terminal` — the old one is still attached to the VM; leave it). Paste:

```bash
cd ~/tta-runs/staging && ./export-run.sh run-calc-A-basic-1 calc-A-basic-1
open ~/tta-runs/calc-A-basic-1/index.html
```

✅ **You should now see:** a list of what was pulled out of the VM (repo, transcripts, stills, recording…), then the **Run Viewer** page opening — a flip-book of the stills with the video below it.

### Step 11. Hand off

Report where the bundle is (`~/tta-runs/calc-A-basic-1` on the VM host). Analysis, token accounting, the time tally, and the run-report card are generated from it (`node scripts/analyze-run.mjs <bundle-dir>`). **Do not delete the VM** — leave it stopped for inspection.

---

## Troubleshooting

| What you see | What it means / what to do |
|---|---|
| Launcher ends with "plain SSH session" text instead of a VM window | You ran it over SSH. Do Step 1 at the VM host's desktop (or via Screen Sharing) and run the printed `tart run` command there. |
| No VM window after Step 2 | In a new VM-host Terminal: `tart list` — if the VM says `running` but there's no window, report it; if `stopped`, run `tart run run-calc-A-basic-1` from a desktop Terminal. |
| Typing goes to the wrong Mac | Click once inside the VM window to type into the VM; click outside it to type on the real Mac. |
| `golden image not found` | The one-time golden-image build hasn't been done on this VM host. |
| Agent sits idle >60s with no question | Persona rule 3: type exactly `continue`. |
| **Anything else** | Stop. Note the exact text and the step number. Leave everything as-is and report. A stopped run that teaches us something is the pilot doing its job. |

---
*Revisions: 1.0 initial · 1.1 tart-run-holds-terminal fix · 1.2 state-based expectations + health checks · 1.3 display-path split · 1.4 generic operator rewrite (platform section, no host specifics) · 1.5 novice-fidelity rewrite: defined terms, per-step ✅ verification, manual-recording warning, zero-tab launcher flow, troubleshooting table.*
