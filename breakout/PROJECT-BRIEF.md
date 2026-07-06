# PROJECT BRIEF — Neon Breakout

A visually striking brick-breaker game. SvelteKit wrapper, HTML5 Canvas core. Neon aesthetic (glowing bricks, particle trails, screen shake). Touch controls for mobile. 3 levels. Build it in THIS repository.

## Features (all required — "done" means every one works)

- Paddle control by mouse, touch, AND keyboard
- Ball physics: angle of reflection varies by where the ball hits the paddle; speed increases per level and per brick-hit streak
- 3 level layouts (different brick patterns, increasing density), level-complete transition between them
- Brick types: normal (1 hit), tough (2 hits, color shift after first hit), indestructible (metal — never breaks, doesn't count toward level completion)
- Powerups drop from broken bricks, fall, and apply on paddle catch: wide paddle, multi-ball, slow-mo — each with an effect duration and expiry
- Scoring + lives: 3 lives, score multiplier for consecutive brick hits without a paddle miss
- Particle effects: brick shatter, ball trail, powerup sparkle
- Neon glow aesthetic (CSS + canvas glow)
- Responsive canvas: scales to viewport, touch-friendly paddle
- Start screen, game-over screen, level-complete transition
- Pause/resume works cleanly (no physics glitches on resume)
- Visual appearance designed from scratch — no reference design exists; visual quality will be judged

## The 4 work lanes

**Lane A — Physics & Collision**
- `src/lib/game/physics.ts` — ball movement, wall bounce, paddle reflection (angle based on hit position)
- `src/lib/game/collision.ts` — ball↔brick AABB, ball↔paddle, powerup↔paddle
- `src/lib/game/gameloop.ts` — requestAnimationFrame loop, delta-time, pause/resume
- Speed curve (ball accelerates per level, per brick-hit-streak)

**Lane B — Bricks, Levels & Powerups**
- `src/lib/game/bricks.ts` — brick grid, types (normal/tough/indestructible), hit tracking
- `src/lib/game/levels.ts` — 3 level layouts (brick pattern arrays)
- `src/lib/game/powerups.ts` — spawn on brick break, fall, paddle collect, effect apply + expire
- Level-complete detection (all breakable bricks gone)

**Lane C — Rendering & VFX**
- `src/lib/game/renderer.ts` — canvas draw loop (paddle, ball, bricks, powerups, UI overlay)
- `src/lib/game/particles.ts` — particle emitter (brick shatter, ball trail, powerup sparkle)
- `src/lib/game/vfx.ts` — screen shake, glow filter, neon palette
- HUD overlay (score, lives, level indicator, multiplier)

**Lane D — Shell, Input & Screens**
- `src/routes/play/+page.svelte` — canvas mount, responsive sizing
- `src/lib/game/input.ts` — mouse, touch, keyboard → normalized paddle position
- `src/lib/game/screens.ts` — start screen, game-over, level-complete (canvas-drawn or overlay)
- `src/lib/game/state.ts` — game state store (score, lives, level, paused, game-over)
- `src/routes/+layout.svelte` — app shell (minimal — game is fullscreen-ish)

## Collision map (where parallel work overlaps)

| Shared concept | Lanes that touch it | What goes wrong without coordination |
|---------------|--------------------|--------------------------------------|
| `gameloop.ts` | A (owns tick), C (draws each frame), D (pause/resume) | Three lanes hooking one loop — who owns `update()` vs `render()` vs `handleInput()`? |
| Game state store | A (writes ball/paddle pos), B (writes brick state), C (reads everything), D (writes score/lives) | Four writers, one store — race conditions or four competing stores |
| Brick data structure | A (reads for collision), B (defines/mutates), C (reads for rendering) | B defines the shape; A and C assume it; schema change = silent breakage |
| Canvas context | C (owns drawing), D (owns canvas element + sizing) | Who creates the canvas? Who sets dimensions? Both think they own it |
| Powerup effects | A (applies speed change), B (spawns them), C (renders them), D (state tracks active) | One feature, four lanes — the quintessential coordination challenge |
| Paddle position | A (uses for collision), C (renders it), D (writes from input) | Three consumers, one producer — three different paddle representations |

## Milestones (ordered dependencies — what needs what, not a prescribed schedule)

1. Lane D ships canvas mount + input + state store (everyone needs the canvas and state)
2. Lane A ships physics (C needs positions to render, B needs collision to break bricks)
3. Lane B ships bricks + levels (C needs brick data to render)
4. Lane C wires rendering (needs all data sources)
5. Integration: powerups cross all 4 lanes — the final coordination test

## Acceptance

`npm install && npm run build` succeeds, the game runs, and every feature above works. No merge conflicts, no duplicate or competing components, no broken imports.
