#!/usr/bin/env node
// prepare-starter.mjs — cross-platform starter preparation (macOS / Linux / Windows).
//
// WHAT THIS DOES: copies a challenge starter (calculator or breakout) to a fresh
// directory and turns it into an initialized git repository with one committed
// baseline — exactly what the downloadable release zips contain. Your agent
// works on top of that baseline, so its git history records everything it does
// from commit zero (that history is the coordination evidence).
//
// WHY NODE: the starters are SvelteKit apps, so Node is already required on any
// machine taking the challenge — one script, every platform, no bash/PowerShell.
//
// REQUIREMENTS: Node ≥ 18 and git on PATH. Nothing else.
//
// USAGE:
//   node scripts/prepare-starter.mjs calculator my-attempt
//   node scripts/prepare-starter.mjs breakout   ../somewhere/fresh
import { cpSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import { join, resolve, dirname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const [project, destArg] = process.argv.slice(2);
const PROJECTS = ['calculator', 'breakout'];
if (!PROJECTS.includes(project ?? '') || !destArg) {
  console.error('usage: node scripts/prepare-starter.mjs <calculator|breakout> <destination-dir>');
  process.exit(1);
}

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(repoRoot, project);
const dest = resolve(destArg);

if (existsSync(dest) && readdirSync(dest).length > 0) {
  console.error(`✗ destination ${dest} exists and is not empty — pick a fresh directory`);
  process.exit(1);
}

const EXCLUDE = new Set(['node_modules', '.svelte-kit', '.git', 'dist', 'build']);
console.log(`▸ copying ${project} starter → ${dest}`);
mkdirSync(dest, { recursive: true });
cpSync(src, dest, {
  recursive: true,
  filter: (p) => !p.split(sep).some((part) => EXCLUDE.has(part)),
});

function git(...args) {
  const r = spawnSync('git', args, { cwd: dest, stdio: 'pipe', encoding: 'utf8' });
  if (r.status !== 0) {
    console.error(`✗ git ${args.join(' ')} failed:\n${r.stderr || r.stdout}`);
    process.exit(1);
  }
  return r.stdout.trim();
}

console.log('▸ initializing git baseline (commit zero — your agent\'s history starts here)');
git('init', '-q', '-b', 'main');
git('-c', 'user.name=wikiTaTa Challenge', '-c', 'user.email=challenge@wikitata.com', 'add', '-A');
git('-c', 'user.name=wikiTaTa Challenge', '-c', 'user.email=challenge@wikitata.com',
    'commit', '-q', '-m', `starter baseline — wikiTaTa Test Your Agent (${project})`);

console.log(`✓ ready: ${dest}`);
console.log(`  baseline commit: ${git('log', '--oneline', '-1')}`);
console.log('');
console.log('Next:');
console.log(`  1. cd ${destArg}`);
console.log('  2. npm install && npm run build     (verify the skeleton builds before you start)');
console.log('  3. Point your agent at this directory and paste the startup instruction');
console.log('     from CHALLENGE.md verbatim. The timer starts at the paste.');
