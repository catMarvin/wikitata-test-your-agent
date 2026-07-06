# The Challenge — rules and the exact startup instruction

Two small apps. Each is deliberately structured as **4 parallel work streams whose files overlap** (see the collision map in each PROJECT-BRIEF.md). Any dev team would parallelize this way — the question is whether your agent setup can actually do it without merge disasters, duplicate components, or a serialized crawl.

## How to run it

1. Download a starter (`calculator-starter.zip` or `breakout-starter.zip` from Releases, or package your own with `scripts/package-starters.sh`). Each starter is an initialized git repository with a committed baseline.
2. Unzip, `cd` in, and start your agent of choice.
3. Paste the startup instruction below **verbatim** — it is the ONLY steering you give. Answer your agent's questions with minimal, sensible answers; never suggest features, tools, or approach.
4. Start a timer at the paste. Record what happens (screen recording recommended).

## The startup instruction (paste exactly; swap the project name for breakout)

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

For **Neon Breakout**, replace the project name in line 2; everything else is identical.

## What to look for (the collision map as a spectator guide)

- Did the agent genuinely parallelize (interleaved commits across lane file-sets, multiple sessions/worktrees) — or quietly serialize?
- Merge conflicts, or files silently overwritten?
- Duplicate/competing components (two layouts, two state stores, two button components)?
- Broken imports when lanes integrate?
- Did dependency order make sense (shell and engine before the things that need them)?

## Fair-play rules

- One instruction, pasted verbatim, identical for every setup you compare.
- Allowed: everything your agent tooling ships with, plus git, your OS's stock tools (tmux/screen included), and node/npm.
- Not allowed: importing pre-built multi-agent coordination frameworks mid-run. (Hand-rolling your own coordination during the run is allowed — it costs you clock time, which is the honest trade-off.)
- Count everything: if your agent spawns sub-agents, their tokens and time count too.

## Scoring (how we judge our own runs — use it if you want comparable numbers)

**Function 40** (feature checklist, build failure = 0) · **Coordination 25** (conflicts −5, duplicate components −3, broken imports −4, rework commits −2, real parallelism scored) · **Design 20** (blind panel on screenshots) · **Efficiency 15** (tokens/$/wall-clock; sliding penalty past the 15-minute target; hard cap 45 min).
