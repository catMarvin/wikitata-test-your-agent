# Capturing a run — platform-agnostic bundle spec

Want your attempt to be comparable (or publishable)? Capture it as a **bundle** — a plain
directory with the layout below. The bundle format is OS- and VM-tool-independent: our
reference harness produces it from macOS VMs, but anything that writes these files is valid.

## Bundle layout

```
<run-id>/                      e.g. calc-A-basic-1/
├── transcripts/               ALL Claude Code session JSONL files for the run
│                              (copy your ~/.claude/projects/<project-dir>/ — include
│                              subagent sessions; they count toward totals)
├── repo/                      the produced project, full git history intact
├── recording.(mov|mp4|mkv)    screen recording, first keystroke to done/cap
├── stills/                    periodic full-screen PNGs (every ~30s) — optional but great
├── manifest.json              environment: OS+build, Node, Claude Code version, model id,
│                              machine, date  (+ "stills": [...] if you captured stills)
├── operator-log.md            every human input, verbatim, with timestamps
└── tier-surface-proof.txt     output of `claude mcp list` (proves what was connected)
```

## Analyze it (any OS)

```bash
node scripts/analyze-run.mjs <path-to-bundle>
```

Writes `analysis/metrics.json` + `analysis/run-report.md`: per-model token totals
(deduped correctly from Claude Code's JSONL), cache read/write split, cost at pinned
public API pricing, tool-call counts, wall-clock, and a report skeleton. Pure Node,
no dependencies — macOS, Linux, and Windows alike.

## Recording + stills — reference commands per OS

The capture *mechanism* is up to you; these are known-good starting points.
(Non-macOS commands are reference implementations — verified syntax, not yet
community-verified in scored runs. PRs with battle-tested versions welcome.)

| | Screen recording | Periodic stills |
|---|---|---|
| **macOS** | QuickTime Player → New Screen Recording (or `ffmpeg -f avfoundation`) | [`scripts/capture-stills.sh`](scripts/capture-stills.sh) (uses `screencapture`) |
| **Linux (X11)** | `ffmpeg -f x11grab -framerate 15 -i :0.0 recording.mkv` | loop `scrot stills/$(printf %04d $n).png` every 30s |
| **Linux (Wayland)** | `wf-recorder -f recording.mkv` (or OBS) | loop `grim stills/$(printf %04d $n).png` every 30s |
| **Windows** | `ffmpeg -f gdigrab -framerate 15 -i desktop recording.mkv` (or Xbox Game Bar, Win+Alt+R) | PowerShell loop with `[System.Windows.Forms]` `CopyFromScreen`, or `ffmpeg -f gdigrab ... -vf fps=1/30 stills/%04d.png` |

## Isolation (what our VM harness adds)

For *scored* comparisons, runs should be contamination-free: a fresh environment per run,
no prior caches, no cross-run residue. Our reference harness gets this from disposable
macOS VMs on an Apple Silicon host (see the runbook). On other platforms, any equivalent
works — a fresh QEMU/KVM guest, a Hyper-V checkpoint, a clean container + fresh OS user,
or a re-imaged machine. Document what you used in `manifest.json`. An instrumented
reference harness for Linux/Windows hosts is on the roadmap — contributions welcome.
