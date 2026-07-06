#!/bin/bash
# Build distributable starter zips. Each zip contains an INITIALIZED git repo
# with one committed baseline — the challenger's agent works on top of it, so
# git history records everything the agent does from commit zero.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
mkdir -p "$DIST"

for proj in calculator breakout; do
  echo "== packaging $proj =="
  STAGE="$(mktemp -d)/$proj"
  mkdir -p "$STAGE"
  rsync -a --exclude node_modules --exclude .svelte-kit --exclude .git \
    "$ROOT/$proj/" "$STAGE/"
  git -C "$STAGE" init -q -b main
  git -C "$STAGE" -c user.name="wikiTaTa Challenge" -c user.email="challenge@wikitata.com" \
    add -A
  git -C "$STAGE" -c user.name="wikiTaTa Challenge" -c user.email="challenge@wikitata.com" \
    commit -q -m "starter baseline — wikiTaTa Test Your Agent ($proj)"
  (cd "$(dirname "$STAGE")" && rm -f "$DIST/$proj-starter.zip" && zip -qr "$DIST/$proj-starter.zip" "$proj")
  echo "   -> dist/$proj-starter.zip"
done

echo "Done. Starters in $DIST"
