# tta-tracker — tier-B token tracking (and nothing else)

The tier-B instrument for the wikiTaTa "Test Your Agent" protocol: tier B = bare Claude Code **plus token tracking only**. It measures the tracking instrument's own overhead (B−A at matched persona) and cross-checks the transcript-JSONL token accounting.

**Binding surface rule (protocol §2.6):** this MCP exposes exactly ONE read-only tool — `tta_token_report`. No cards, no tasks, no locks, no board, no messaging, no memory, no agent dispatch. A tier-B run whose `tools/list` shows anything more is VOID. Capture is passive, in a Stop hook — the tool only reads.

## Install (golden image B) — novice-runnable

1. ```bash
   cd tools/tta-tracker && npm install
   ```
   Expect: packages install without error.
2. Register the MCP server:
   ```bash
   claude mcp add -s user tta-tracker node /FULL/PATH/TO/tools/tta-tracker/index.js
   ```
   Expect: `claude mcp list` shows exactly one server: `tta-tracker`.
3. Install the passive Stop hook — merge into `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "Stop": [
         { "hooks": [ { "type": "command", "command": "node /FULL/PATH/TO/tools/tta-tracker/hooks/track-turn.mjs" } ] }
       ]
     }
   }
   ```
4. Verify end-to-end: start `claude`, say "hello", exit, then:
   ```bash
   cat ~/tta/turn_stats.jsonl
   ```
   Expect: one JSON line with your session id and token counts. In a new `claude` session, calling `tta_token_report` returns the same numbers.

## Files

- `index.js` — the MCP server (stdio). Reads `~/tta/turn_stats.jsonl` (override: `TTA_STATS_FILE`).
- `hooks/track-turn.mjs` — Stop hook; re-scans the session transcript and appends one cumulative snapshot per Stop. Last line per session = current truth (idempotent; a missed/duplicate event can't corrupt totals).
- `test/tracker.test.mjs` — fixture-based tests for both.
