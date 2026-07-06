#!/usr/bin/env node
// tta-tracker passive capture — Claude Code Stop hook.
//
// On every Stop event, re-scans the session transcript JSONL and appends ONE
// cumulative snapshot line to ~/tta/turn_stats.jsonl:
//   {ts, session_id, turns, input_tokens, output_tokens,
//    cache_read_tokens, cache_creation_tokens}
// Idempotent by design: the LAST line per session is always the full truth,
// so a missed or duplicated Stop event can never corrupt the accounting.
// The transcript itself remains the primary instrument (protocol §4) — this
// file is the tier-B cross-check.

import { readFileSync, mkdirSync, appendFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';

const STATS_FILE = process.env.TTA_STATS_FILE || join(homedir(), 'tta', 'turn_stats.jsonl');

let input = '';
try { input = readFileSync(0, 'utf8'); } catch { process.exit(0); }
let hook;
try { hook = JSON.parse(input); } catch { process.exit(0); }

const transcriptPath = hook.transcript_path;
const sessionId = hook.session_id || 'unknown';
if (!transcriptPath || !existsSync(transcriptPath)) process.exit(0);

const totals = { turns: 0, input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, cache_creation_tokens: 0 };
for (const line of readFileSync(transcriptPath, 'utf8').split('\n')) {
  if (!line) continue;
  let entry; try { entry = JSON.parse(line); } catch { continue; }
  const usage = entry?.message?.usage;
  if (entry?.type !== 'assistant' || !usage) continue;
  totals.turns += 1;
  totals.input_tokens += usage.input_tokens || 0;
  totals.output_tokens += usage.output_tokens || 0;
  totals.cache_read_tokens += usage.cache_read_input_tokens || 0;
  totals.cache_creation_tokens += usage.cache_creation_input_tokens || 0;
}

mkdirSync(dirname(STATS_FILE), { recursive: true });
appendFileSync(STATS_FILE, JSON.stringify({ ts: new Date().toISOString(), session_id: sessionId, ...totals }) + '\n');
