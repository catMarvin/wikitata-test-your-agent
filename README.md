# wikiTaTa — Test Your Agent

**Can your agent build this in parallel?**

Two small SvelteKit apps — a [Pocket Scientific Calculator](calculator/PROJECT-BRIEF.md) and a [Neon Breakout game](breakout/PROJECT-BRIEF.md). Each is specified as **4 parallel work streams that overlap on shared files** (state stores, layouts, the game loop, powerups that cross every lane). Realistic, not a trap: it's exactly how a real team would split the work.

Without coordination infrastructure, agents facing this either go **serial** (slow) or **parallel-and-broken** (merge disasters, duplicate components, conflicting state). The point of this repo is to let you find out which one yours does.

## Quick start

```bash
git clone https://github.com/catMarvin/wikitata-test-your-agent.git
cd wikitata-test-your-agent
./scripts/package-starters.sh        # builds dist/calculator-starter.zip + dist/breakout-starter.zip
```

Unzip a starter somewhere fresh, point your agent at it, and paste the startup instruction from [CHALLENGE.md](CHALLENGE.md) verbatim. Timer starts at the paste. Target: **15 minutes**, all four lanes shipped, clean integration, working app.

## What's in a starter

A minimal, buildable SvelteKit skeleton (`npm install && npm run build` passes as-is), the full `PROJECT-BRIEF.md` (features, the 4 lanes, the collision map, dependency-ordered milestones), and a committed git baseline — so the git history of what your agent does IS the coordination evidence.

## Repo layout

- [`calculator/`](calculator/) — starter project 1 (+ its brief)
- [`breakout/`](breakout/) — starter project 2 (+ its brief)
- [`CHALLENGE.md`](CHALLENGE.md) — rules, the verbatim startup instruction, fair-play lines, scoring rubric
- [`scripts/package-starters.sh`](scripts/package-starters.sh) — builds the distributable starter zips

## Why this exists

We build [wikiTaTa](https://wikitata.com) — a coordination platform (shared memory cards, a live now-board, work lanes, file locks, agent-to-agent messaging) for AI agents. Our claim: **an average user with wikiTaTa beats a power user without it** on exactly this kind of work. This challenge is how we're testing that claim on ourselves — same model, same prompt, same task, the platform as the only variable — and how you can test your own setup. Results from our instrumented runs will be published on the challenge page along with full capture bundles.

## License

MIT — see [LICENSE](LICENSE).
