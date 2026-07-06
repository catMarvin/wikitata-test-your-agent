#!/usr/bin/env node
// tta-tracker — the tier-B MCP server for the wikiTaTa "Test Your Agent" protocol.
//
// BINDING SURFACE SPEC (protocol §2.6, card 83d523be): this server exposes
// EXACTLY ONE read-only tool, `tta_token_report`. No resources, no prompts,
// no state written by the tool, no coordination power of any kind. A tier-B
// run whose tools/list shows anything more is VOID.
//
// Token capture itself is PASSIVE and lives in hooks/track-turn.mjs (a Claude
// Code Stop hook) — this tool only READS what the hook wrote.

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

const STATS_FILE = process.env.TTA_STATS_FILE || join(homedir(), 'tta', 'turn_stats.jsonl');

function readSnapshots() {
  if (!existsSync(STATS_FILE)) return [];
  return readFileSync(STATS_FILE, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => { try { return JSON.parse(line); } catch { return null; } })
    .filter(Boolean);
}

const server = new McpServer({
  name: 'tta-tracker',
  version: '1.0.0',
  description: 'wikiTaTa Test Your Agent — token tracking ONLY (tier B). One read-only tool; zero coordination power.'
});

server.registerTool('tta_token_report', {
  title: 'Report cumulative token usage for this machine\'s Claude Code sessions',
  description: 'Read-only. Returns per-session and total token usage captured by the passive Stop hook (input/output/cache tokens + turn counts). Provides no memory, no coordination, no writes.',
  inputSchema: z.object({
    session_id: z.string().optional().describe('Limit the report to one session id (default: all sessions)')
  })
}, async ({ session_id }) => {
  const snaps = readSnapshots();
  // The hook writes one full-transcript snapshot per Stop event; the LAST
  // snapshot per session is that session's current cumulative truth.
  const latestBySession = new Map();
  for (const s of snaps) {
    if (session_id && s.session_id !== session_id) continue;
    latestBySession.set(s.session_id, s);
  }
  const sessions = [...latestBySession.values()];
  const total = sessions.reduce((acc, s) => ({
    input_tokens: acc.input_tokens + (s.input_tokens || 0),
    output_tokens: acc.output_tokens + (s.output_tokens || 0),
    cache_read_tokens: acc.cache_read_tokens + (s.cache_read_tokens || 0),
    cache_creation_tokens: acc.cache_creation_tokens + (s.cache_creation_tokens || 0),
    turns: acc.turns + (s.turns || 0)
  }), { input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, cache_creation_tokens: 0, turns: 0 });
  return {
    content: [{
      type: 'text',
      text: JSON.stringify({ ok: true, stats_file: STATS_FILE, sessions, total }, null, 2)
    }]
  };
});

const transport = new StdioServerTransport();
await server.connect(transport);
