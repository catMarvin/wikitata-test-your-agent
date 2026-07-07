#!/usr/bin/env node
// analyze-run.mjs — token accounting + run-report skeleton for a TTA capture bundle.
// Protocol §4: the transcript JSONL is the single token instrument for every tier;
// turn_stats.jsonl (tier B/C) is reported as a cross-check, never the primary number.
//
// Usage: node scripts/analyze-run.mjs <bundle-dir> [--run-id <id>] [--plan-usd <monthly-$>]
//   <bundle-dir> is an export-run.sh output dir (transcripts/, manifest.json, ...).
//   Writes <bundle-dir>/analysis/metrics.json and <bundle-dir>/analysis/run-report.md.
//
// Accounting rules (adopted §4 amendments):
//   - ALL session JSONLs found under transcripts/ are summed (subagent symmetry rule).
//   - API retries/errors are counted toward totals and reported separately (A6).
//   - Costs at pinned public API pricing; plan translation via --plan-usd (C3).
//   - Report carries a witness table (C5) and the mandatory limitations section (C4).

import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, basename } from 'node:path';

// ---- pinned public API pricing (USD per MTok) --------------------------------
// Source: Anthropic public pricing, pinned 2026-07-07. Cache: read = 0.1x input;
// write = 1.25x input (5-minute TTL) or 2x input (1-hour TTL).
const PRICING_DATE = '2026-07-07';
const PRICING = [
  { prefix: 'claude-fable-5',    in: 10.0, out: 50.0 },
  { prefix: 'claude-mythos-5',   in: 10.0, out: 50.0 },
  { prefix: 'claude-opus-4-8',   in: 5.0,  out: 25.0 },
  { prefix: 'claude-opus-4-7',   in: 5.0,  out: 25.0 },
  { prefix: 'claude-opus-4-6',   in: 5.0,  out: 25.0 },
  { prefix: 'claude-opus-4-5',   in: 5.0,  out: 25.0 },
  { prefix: 'claude-sonnet-5',   in: 3.0,  out: 15.0 },  // intro $2/$10 through 2026-08-31 NOT applied — sticker price pinned
  { prefix: 'claude-sonnet-4-6', in: 3.0,  out: 15.0 },
  { prefix: 'claude-sonnet-4-5', in: 3.0,  out: 15.0 },
  { prefix: 'claude-haiku-4-5',  in: 1.0,  out: 5.0  },
];
const CACHE_READ_X = 0.1, CACHE_5M_X = 1.25, CACHE_1H_X = 2.0;

function priceFor(model) {
  const row = PRICING.find(p => model.startsWith(p.prefix));
  return row || null;
}

// ---- collect transcripts ------------------------------------------------------
const args = process.argv.slice(2);
const bundleDir = args.find(a => !a.startsWith('--'));
if (!bundleDir) { console.error('usage: analyze-run.mjs <bundle-dir> [--run-id <id>] [--plan-usd <n>]'); process.exit(1); }
const flag = name => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
const runId = flag('run-id') || basename(bundleDir.replace(/\/+$/, ''));
const planUsd = flag('plan-usd') ? Number(flag('plan-usd')) : null;

function walk(dir, out = []) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    const s = statSync(p);
    if (s.isDirectory()) walk(p, out);
    else if (e.endsWith('.jsonl')) out.push(p);
  }
  return out;
}

const txDir = join(bundleDir, 'transcripts');
if (!existsSync(txDir)) { console.error(`no transcripts/ under ${bundleDir} — is this an export-run.sh bundle?`); process.exit(1); }
const files = walk(txDir);
if (!files.length) { console.error('no .jsonl transcripts found'); process.exit(1); }

// ---- parse ---------------------------------------------------------------------
// Claude Code writes ONE JSONL LINE PER CONTENT BLOCK of an assistant message,
// each repeating the same message.id and the same usage object. Summing naively
// double-counts. We dedupe on message.id (last occurrence wins).
const byMessageId = new Map();       // message.id -> {model, usage, ts, file}
const toolCalls = {};                // tool name -> count
const perFile = {};                  // relative file -> {lines, assistantMsgs}
let apiErrorLines = 0;               // retry/error signal (A6 amendment)
let userTurns = 0;
let firstUserTs = null, minTs = null, maxTs = null;
let badLines = 0;
const allEventTs = [];               // every timestamped transcript entry (idle analysis)
const humanInputTs = [];             // real operator inputs (not tool_results)

for (const f of files) {
  const rel = relative(bundleDir, f);
  perFile[rel] = { lines: 0, assistantMsgs: 0 };
  for (const line of readFileSync(f, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    perFile[rel].lines++;
    let e;
    try { e = JSON.parse(line); } catch { badLines++; continue; }
    const ts = e.timestamp ? Date.parse(e.timestamp) : NaN;
    if (!Number.isNaN(ts)) {
      if (minTs === null || ts < minTs) minTs = ts;
      if (maxTs === null || ts > maxTs) maxTs = ts;
      allEventTs.push(ts);
    }
    if (e.type === 'user' && !e.isMeta) {
      const c = e.message?.content;
      const isToolResult = Array.isArray(c) && c.some(b => b?.type === 'tool_result');
      if (!isToolResult) {
        userTurns++;
        if (firstUserTs === null && !Number.isNaN(ts)) firstUserTs = ts;
        if (!Number.isNaN(ts)) humanInputTs.push(ts);
      }
    }
    if (e.type === 'assistant' && e.message) {
      if (e.isApiErrorMessage) { apiErrorLines++; continue; }
      const m = e.message;
      for (const b of Array.isArray(m.content) ? m.content : []) {
        if (b.type === 'tool_use') toolCalls[b.name] = (toolCalls[b.name] || 0) + 1;
      }
      if (m.id && m.usage) {
        if (!byMessageId.has(m.id)) perFile[rel].assistantMsgs++;
        byMessageId.set(m.id, { model: m.model || 'unknown', usage: m.usage, ts, file: rel });
      }
    }
  }
}

// ---- aggregate -----------------------------------------------------------------
const perModel = {};
for (const { model, usage } of byMessageId.values()) {
  const t = (perModel[model] ||= {
    apiMessages: 0, input: 0, output: 0, cacheRead: 0, cacheWrite5m: 0, cacheWrite1h: 0, cacheWriteUnattributed: 0,
  });
  t.apiMessages++;
  t.input += usage.input_tokens || 0;
  t.output += usage.output_tokens || 0;
  t.cacheRead += usage.cache_read_input_tokens || 0;
  const cc = usage.cache_creation;
  if (cc && (cc.ephemeral_5m_input_tokens != null || cc.ephemeral_1h_input_tokens != null)) {
    t.cacheWrite5m += cc.ephemeral_5m_input_tokens || 0;
    t.cacheWrite1h += cc.ephemeral_1h_input_tokens || 0;
  } else {
    // older format: only the total is present; TTL unknown -> priced at 5m rate, flagged
    t.cacheWriteUnattributed += usage.cache_creation_input_tokens || 0;
  }
}

let unknownModels = [];
for (const [model, t] of Object.entries(perModel)) {
  const p = priceFor(model);
  if (!p) { unknownModels.push(model); t.costUsd = null; continue; }
  t.costUsd =
    (t.input * p.in + t.output * p.out +
     t.cacheRead * p.in * CACHE_READ_X +
     t.cacheWrite5m * p.in * CACHE_5M_X +
     t.cacheWrite1h * p.in * CACHE_1H_X +
     t.cacheWriteUnattributed * p.in * CACHE_5M_X) / 1e6;
}

const sum = k => Object.values(perModel).reduce((a, t) => a + t[k], 0);
const totals = {
  apiMessages: sum('apiMessages'),
  input: sum('input'),
  output: sum('output'),
  cacheRead: sum('cacheRead'),
  cacheWrite: sum('cacheWrite5m') + sum('cacheWrite1h') + sum('cacheWriteUnattributed'),
  costUsd: unknownModels.length ? null : Object.values(perModel).reduce((a, t) => a + t.costUsd, 0),
};
const promptTotal = totals.input + totals.cacheRead + totals.cacheWrite;
const cachedRatio = promptTotal ? totals.cacheRead / promptTotal : 0;

// ---- cross-checks (B/C) ----------------------------------------------------------
let trackerCheck = null;
const trackerPath = join(bundleDir, 'turn_stats.jsonl');
if (existsSync(trackerPath)) {
  let tIn = 0, tOut = 0, tRows = 0;
  for (const line of readFileSync(trackerPath, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    try {
      const r = JSON.parse(line);
      tRows++;
      tIn += (r.input_tokens || 0) + (r.cache_read_input_tokens || 0) + (r.cache_creation_input_tokens || 0);
      tOut += r.output_tokens || 0;
    } catch { /* skip */ }
  }
  trackerCheck = { rows: tRows, promptTokens: tIn, outputTokens: tOut,
    deltaPromptPct: promptTotal ? +(100 * (tIn - promptTotal) / promptTotal).toFixed(2) : null,
    deltaOutputPct: totals.output ? +(100 * (tOut - totals.output) / totals.output).toFixed(2) : null };
}

let manifest = null;
const manifestPath = join(bundleDir, 'manifest.json');
if (existsSync(manifestPath)) { try { manifest = JSON.parse(readFileSync(manifestPath, 'utf8')); } catch { /* keep null */ } }

// ---- wall clock ------------------------------------------------------------------
const fmt = t => t === null ? 'unknown' : new Date(t).toISOString();
const durMin = (a, b) => (a !== null && b !== null) ? +((b - a) / 60000).toFixed(1) : null;

// ---- time tally: harness event logs + transcript-derived idle/latency -------------
// Sources: run-times.log (host events from run-pilot.sh) + guest-run-times.log
// (in-VM events from the setup block's tl() helper) + the transcript itself.
const timeline = [];
for (const f of ['run-times.log', 'guest-run-times.log']) {
  const p = join(bundleDir, f);
  if (!existsSync(p)) continue;
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    const parts = line.split('\t');
    const t = Date.parse(parts[0]);
    if (parts.length >= 3 && !Number.isNaN(t)) timeline.push({ t, src: parts[1], event: parts.slice(2).join(' ') });
  }
}
if (firstUserTs !== null) timeline.push({ t: firstUserTs, src: 'transcript', event: 'first_user_message (clock start)' });
if (maxTs !== null) timeline.push({ t: maxTs, src: 'transcript', event: 'last_transcript_event' });
timeline.sort((a, b) => a.t - b.t);

allEventTs.sort((a, b) => a - b);
const IDLE_MS = 60_000;
const idleGaps = [];
for (let i = 1; i < allEventTs.length; i++) {
  const gap = allEventTs[i] - allEventTs[i - 1];
  if (gap > IDLE_MS) idleGaps.push({ from: fmt(allEventTs[i - 1]), to: fmt(allEventTs[i]), seconds: Math.round(gap / 1000) });
}
const idleTotalSec = idleGaps.reduce((a, g) => a + g.seconds, 0);
// operator latency: time from the previous transcript event to each human input
const opWaitsSec = [];
for (const t of humanInputTs) {
  let prev = null;
  for (const x of allEventTs) { if (x < t) prev = x; else break; }
  if (prev !== null) opWaitsSec.push((t - prev) / 1000);
}
opWaitsSec.sort((a, b) => a - b);
const median = arr => arr.length ? arr[Math.floor(arr.length / 2)] : null;
const evOf = name => { const e = timeline.find(x => x.event.startsWith(name)); return e ? e.t : null; };
const timing = {
  script_start: fmt(evOf('script_start')),
  vm_boot: fmt(evOf('vm_boot_exec')),
  guest_setup_start: fmt(evOf('guest_setup_start')),
  claude_launch: fmt(evOf('claude_launch')),
  clock_start_first_user_message: fmt(firstUserTs),
  run_end_marker: fmt(evOf('run_end')),
  last_transcript_event: fmt(maxTs),
  minutes_full_sequence: durMin(evOf('script_start') ?? firstUserTs, evOf('run_end') ?? maxTs),
  minutes_run_window: durMin(firstUserTs, maxTs),
  idle_gaps_over_60s: idleGaps,
  idle_total_seconds: idleTotalSec,
  operator_latency_seconds: { n: opWaitsSec.length, median: median(opWaitsSec), max: opWaitsSec.length ? opWaitsSec[opWaitsSec.length - 1] : null },
  harness_log_events: timeline.length,
};

// ---- outputs ---------------------------------------------------------------------
const metrics = {
  run_id: runId, generated_at: null, // stamped by the operator/report author, not the script (no clock dependence in CI)
  pricing_date: PRICING_DATE,
  transcripts: perFile,
  bad_lines: badLines,
  api_error_lines: apiErrorLines,
  user_turns: userTurns,
  per_model: perModel,
  totals: { ...totals, prompt_total: promptTotal, cached_ratio: +cachedRatio.toFixed(4) },
  wall_clock: { first_event: fmt(minTs), first_user_message: fmt(firstUserTs), last_event: fmt(maxTs),
    minutes_first_user_to_last: durMin(firstUserTs, maxTs) },
  tool_calls: toolCalls,
  tracker_cross_check: trackerCheck,
  unknown_models: unknownModels,
  manifest_present: !!manifest,
  timing,
};

const outDir = join(bundleDir, 'analysis');
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'metrics.json'), JSON.stringify(metrics, null, 2));

// human-readable time tally (output-run-times)
const secFmt = s => s == null ? 'n/a' : (s >= 90 ? `${(s / 60).toFixed(1)} min` : `${Math.round(s)}s`);
const tallyLines = [
  `TIME TALLY — ${runId}`,
  ``,
  `Merged event timeline (${timeline.length} events: host log + guest log + transcript anchors):`,
  ...timeline.map(e => `  ${new Date(e.t).toISOString()}  [${e.src}]  ${e.event}`),
  ``,
  `Totals:`,
  `  full sequence (first harness command -> run end):  ${timing.minutes_full_sequence ?? 'n/a'} min`,
  `  run window (clock start -> last transcript event): ${timing.minutes_run_window ?? 'n/a'} min`,
  `  idle gaps >60s inside the transcript: ${idleGaps.length} totaling ${secFmt(idleTotalSec)}`,
  ...idleGaps.map(g => `    ${g.from} -> ${g.to}  (${secFmt(g.seconds)})`),
  `  operator response latency: n=${timing.operator_latency_seconds.n}, median ${secFmt(timing.operator_latency_seconds.median)}, max ${secFmt(timing.operator_latency_seconds.max)}`,
  timeline.length <= 2 ? `` : null,
  timeline.some(e => e.src === 'host' || e.src === 'guest') ? '' :
    '  NOTE: no harness timing logs in this bundle (run predates run-times.log) — transcript-derived numbers only.',
].filter(l => l !== null);
writeFileSync(join(outDir, 'run-times.txt'), tallyLines.join('\n') + '\n');

const usd = v => v == null ? 'n/a (unknown model id)' : `$${v.toFixed(4)}`;
const modelRows = Object.entries(perModel).map(([m, t]) =>
  `| ${m} | ${t.apiMessages} | ${t.input.toLocaleString()} | ${t.output.toLocaleString()} | ${t.cacheRead.toLocaleString()} | ${(t.cacheWrite5m + t.cacheWrite1h + t.cacheWriteUnattributed).toLocaleString()} | ${usd(t.costUsd)} |`).join('\n');
const toolRows = Object.entries(toolCalls).sort((a, b) => b[1] - a[1]).map(([n, c]) => `| ${n} | ${c} |`).join('\n') || '| (none) | |';
const planLine = planUsd
  ? `At a $${planUsd}/month subscription, this run's API-equivalent cost is ${(totals.costUsd != null) ? (100 * totals.costUsd / planUsd).toFixed(2) + '% of one month' : 'n/a'}.`
  : `Plan translation (§4-C3): re-run with --plan-usd <monthly-$> to express this run as a fraction of a subscription plan.`;

const report = `# Run report — ${runId}

> Skeleton generated by \`scripts/analyze-run.mjs\` (protocol §4: script-generated skeleton + operator notes).
> Pricing pinned ${PRICING_DATE}. Cache: read 0.1x input; write 1.25x (5m) / 2x (1h).

## Summary (operator fills in)

- **Outcome:** _DONE / capped / voided — operator_
- **One-line story:** _operator_

## Token accounting (single instrument: transcript JSONL, ${files.length} session file${files.length === 1 ? '' : 's'} summed)

| Model | API msgs | Input (fresh) | Output | Cache read | Cache write | Cost |
|---|---|---|---|---|---|---|
${modelRows}
| **TOTAL** | **${totals.apiMessages}** | **${totals.input.toLocaleString()}** | **${totals.output.toLocaleString()}** | **${totals.cacheRead.toLocaleString()}** | **${totals.cacheWrite.toLocaleString()}** | **${usd(totals.costUsd)}** |

- Prompt tokens total (fresh + cache read + cache write): **${promptTotal.toLocaleString()}**
- Fresh-vs-cached: **${(100 * cachedRatio).toFixed(1)}% served from cache**
- Retry/error API lines (counted separately per amendment A6): **${apiErrorLines}**
- User turns (operator inputs incl. answer-bank replies): **${userTurns}**
- ${planLine}
${unknownModels.length ? `- ⚠️ Unknown model ids (no pinned price): ${unknownModels.join(', ')} — add to PRICING and re-run.\n` : ''}
## Wall clock

- First user message (≈ instruction paste): ${fmt(firstUserTs)}
- Last transcript event: ${fmt(maxTs)}
- Duration (first user → last event): ${durMin(firstUserTs, maxTs) ?? 'unknown'} min
- **Authoritative clock is the operator log** (start = instruction paste, end = DONE/cap); the transcript window above is the cross-check.

## Time tally

- Full sequence (first harness command → run end): **${timing.minutes_full_sequence ?? 'n/a'} min** · run window (clock start → last transcript event): **${timing.minutes_run_window ?? 'n/a'} min**
- Idle gaps >60s: **${idleGaps.length}** totaling **${Math.round(idleTotalSec / 60)} min** · operator latency: median ${timing.operator_latency_seconds.median ?? 'n/a'}s, max ${timing.operator_latency_seconds.max ?? 'n/a'}s (n=${timing.operator_latency_seconds.n})
- Full merged timeline: \`analysis/run-times.txt\`

## Tool calls

| Tool | Calls |
|---|---|
${toolRows}

## Instrument cross-check (§4.4 — tiers B/C only)

${trackerCheck
  ? `tta-tracker turn_stats.jsonl: ${trackerCheck.rows} rows; prompt ${trackerCheck.promptTokens.toLocaleString()} (Δ ${trackerCheck.deltaPromptPct}% vs transcript), output ${trackerCheck.outputTokens.toLocaleString()} (Δ ${trackerCheck.deltaOutputPct}%).`
  : `No turn_stats.jsonl in bundle — expected for tier A (transcript is the sole instrument).`}

## Witness table (§4 amendment C5)

| Witness | Present in bundle | Fidelity/scope note |
|---|---|---|
| Screen recording | ${existsSync(join(bundleDir, 'recording.mov')) ? 'yes' : 'NO'} | full-fidelity UI, no token data |
| Transcript JSONL | yes (${files.length}) | primary token instrument, per-turn usage |
| Produced repo git history | ${existsSync(join(bundleDir, 'repo')) ? 'yes' : 'NO'} | parallelism/coordination evidence (§5) |
| Operator log | _operator attaches_ | authoritative human-input + clock record |
| Stills | ${existsSync(join(bundleDir, 'stills')) ? 'yes' : 'NO'} | publishable key moments |
| Tier-surface proof | ${existsSync(join(bundleDir, 'tier-surface-proof.txt')) ? 'yes' : 'NO'} | proves tier (mcp list capture) |
| Server-side traffic/turn stats | ${trackerCheck ? 'yes' : 'no (tier A)'} | different fidelity/scope than in-guest capture |

## Environment manifest

${manifest ? '```json\n' + JSON.stringify(manifest, null, 2) + '\n```' : '_No manifest.json in bundle — attach the environment manifest (macOS build, Node, CC version, model id, golden image, clone id, date, host)._'}

## Descriptive timeline (non-scored, §4 amendment OP1)

_Operator/analyst: optional narrative timeline. The scored phase-split was DROPPED (3-2); do not score phases._

## Anomalies & protocol friction

_Operator: every deviation, stall, confusion, or runbook gap observed. These feed protocol amendments._

## Limitations (MANDATORY in all published results — §4 amendment C4)

- n=1 per cell: this is a demonstration, not statistics (lineage: card 507f4456).
- Single operator performed all runs.
- Platform-default behavior unmodified (no sub-agent budget).
- Network envelope: _disclose the run's network conditions_.
- Model snapshot: response-level model id recorded per turn (see table above); matrix runs inside a tight calendar window.
- Costs at pinned API pricing (${PRICING_DATE}) AND translated to subscription-plan equivalents (see summary line).
`;

writeFileSync(join(outDir, 'run-report.md'), report);
console.log(`✓ ${join(outDir, 'metrics.json')}`);
console.log(`✓ ${join(outDir, 'run-report.md')}`);
console.log(`  ${files.length} transcript file(s), ${totals.apiMessages} API messages, ${promptTotal.toLocaleString()} prompt tokens, ${totals.output.toLocaleString()} output, cost ${usd(totals.costUsd)}${unknownModels.length ? ' [UNKNOWN MODELS — cost incomplete]' : ''}`);
