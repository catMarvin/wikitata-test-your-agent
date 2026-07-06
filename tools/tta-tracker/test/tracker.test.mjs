#!/usr/bin/env node
// tta-tracker tests: (1) the Stop hook parses a transcript fixture and writes a
// correct snapshot; (2) the MCP server serves EXACTLY one tool and reports the
// numbers the hook wrote. Run: npm test
import { execFileSync, spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import assert from 'node:assert';

const HERE = dirname(fileURLToPath(import.meta.url));
const tmp = mkdtempSync(join(tmpdir(), 'tta-test-'));
const statsFile = join(tmp, 'turn_stats.jsonl');
const transcript = join(tmp, 'transcript.jsonl');

// --- fixture transcript: 2 assistant turns + noise lines ---
writeFileSync(transcript, [
  JSON.stringify({ type: 'user', message: { content: 'hi' } }),
  JSON.stringify({ type: 'assistant', message: { usage: { input_tokens: 100, output_tokens: 50, cache_read_input_tokens: 10, cache_creation_input_tokens: 5 } } }),
  JSON.stringify({ type: 'system' }),
  JSON.stringify({ type: 'assistant', message: { usage: { input_tokens: 200, output_tokens: 75 } } }),
  'not json at all'
].join('\n'));

// --- 1. hook writes a correct cumulative snapshot ---
execFileSync('node', [join(HERE, '..', 'hooks', 'track-turn.mjs')], {
  input: JSON.stringify({ session_id: 'sess-1', transcript_path: transcript }),
  env: { ...process.env, TTA_STATS_FILE: statsFile }
});
const snap = JSON.parse(readFileSync(statsFile, 'utf8').trim().split('\n').at(-1));
assert.equal(snap.session_id, 'sess-1');
assert.equal(snap.turns, 2);
assert.equal(snap.input_tokens, 300);
assert.equal(snap.output_tokens, 125);
assert.equal(snap.cache_read_tokens, 10);
assert.equal(snap.cache_creation_tokens, 5);
console.log('PASS hook snapshot');

// --- idempotence: a second Stop appends; LAST line stays the truth ---
execFileSync('node', [join(HERE, '..', 'hooks', 'track-turn.mjs')], {
  input: JSON.stringify({ session_id: 'sess-1', transcript_path: transcript }),
  env: { ...process.env, TTA_STATS_FILE: statsFile }
});
const lines = readFileSync(statsFile, 'utf8').trim().split('\n');
assert.equal(lines.length, 2);
assert.equal(JSON.parse(lines.at(-1)).input_tokens, 300);
console.log('PASS hook idempotence');

// --- 2. MCP server over stdio: initialize -> tools/list -> tools/call ---
const server = spawn('node', [join(HERE, '..', 'index.js')], {
  env: { ...process.env, TTA_STATS_FILE: statsFile },
  stdio: ['pipe', 'pipe', 'inherit']
});
const send = (obj) => server.stdin.write(JSON.stringify(obj) + '\n');
const responses = [];
let buf = '';
server.stdout.on('data', (d) => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx); buf = buf.slice(idx + 1);
    if (line.trim()) { try { responses.push(JSON.parse(line)); } catch {} }
  }
});

send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'tta-test', version: '1.0.0' } } });
await new Promise(r => setTimeout(r, 700));
send({ jsonrpc: '2.0', method: 'notifications/initialized' });
send({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
send({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'tta_token_report', arguments: {} } });
await new Promise(r => setTimeout(r, 1200));
server.kill();

const toolsList = responses.find(r => r.id === 2);
assert.ok(toolsList, 'tools/list answered');
assert.equal(toolsList.result.tools.length, 1, 'EXACTLY one tool (binding surface spec)');
assert.equal(toolsList.result.tools[0].name, 'tta_token_report');
console.log('PASS surface: exactly one tool');

const call = responses.find(r => r.id === 3);
assert.ok(call, 'tools/call answered');
const report = JSON.parse(call.result.content[0].text);
assert.equal(report.total.input_tokens, 300);
assert.equal(report.total.output_tokens, 125);
assert.equal(report.sessions.length, 1);
console.log('PASS report numbers match hook capture');

console.log('ALL TESTS PASS');
