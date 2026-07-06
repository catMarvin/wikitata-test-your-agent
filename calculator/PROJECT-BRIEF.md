# PROJECT BRIEF — Pocket Scientific Calculator

A mobile-friendly scientific calculator with a history tape. SvelteKit single-page app, responsive, dark/light theme toggle. Build it in THIS repository.

## Features (all required — "done" means every one works)

- Standard arithmetic: `+ − × ÷`, decimals, parentheses, correct order of operations (`3+4×2 = 11`)
- Scientific mode toggle: `sin, cos, tan, log, ln, √, x², xⁿ, π, e`, factorial
- Memory: `M+`, `M−`, `MR`, `MC`
- History tape: scrollable list of past calculations; clearable; copy a result back from history
- History persists across page refresh (localStorage)
- Keyboard entry works (digits, operators, Enter, Escape)
- Responsive: phone-first (375px), scales to desktop (1280px)
- Theme toggle (dark/light), persisted
- Graceful error handling: divide by zero and malformed expressions never crash; the display shows something sane
- Subtle animations (button press, result slide-in, history append)
- Visual appearance designed from scratch — no reference design exists; visual quality will be judged

## The 4 work lanes

**Lane A — Math Engine + Eval**
- `src/lib/engine.ts` — tokenizer, parser, evaluator (no `eval()`)
- `src/lib/scientific.ts` — trig, log, factorial, constants
- `src/lib/memory.ts` — M+/M−/MR/MC store
- Tests for engine accuracy

**Lane B — Calculator UI**
- `src/routes/calc/+page.svelte` — main calculator view
- Display component (current expression + result)
- Button grid (standard + scientific toggle)
- Key event handling (keyboard support)

**Lane C — History & Persistence**
- `src/lib/stores/history.ts` — calculation history store
- `src/lib/components/HistoryPanel.svelte` — scrollable tape
- localStorage persistence (survive refresh)
- Clear history, copy result from history

**Lane D — Shell, Theme & Responsive**
- `src/routes/+layout.svelte` — app shell, nav
- `src/lib/styles/theme.ts` — dark/light CSS variables
- `src/lib/components/ThemeToggle.svelte`
- `src/app.css` — responsive breakpoints, base typography
- Mobile viewport, touch-friendly button sizing

## Collision map (where parallel work overlaps)

| Shared file/concept | Lanes that touch it | What goes wrong without coordination |
|---------------------|--------------------|--------------------------------------|
| `stores/history.ts` | A (writes results), C (reads/displays) | A defines the store shape, C assumes a different shape |
| `+layout.svelte` | B (mounts calc), D (builds shell) | Both create the layout wrapper — merge conflict or overwrite |
| Button component | B (builds buttons), D (sizes/themes them) | B hardcodes sizes, D sets responsive sizes — competing twins |
| `app.css` | B, C, D all add styles | Three parallel edits; last writer wins = broken styles |
| Engine API shape | A (exports), B (imports), C (imports) | If A changes the return type, B and C break silently |
| Display component | A (feeds it data), B (builds it) | Who owns the display? Both think they do |

## Milestones (ordered dependencies — what needs what, not a prescribed schedule)

1. Lane D ships shell + theme (others need the layout to mount into)
2. Lane A ships engine (B and C need the API)
3. Lanes B + C can run in parallel once D and A are done
4. Integration: connect all routes, verify responsive, verify history writes

## Acceptance

`npm install && npm run build` succeeds, the app runs, and every feature above works. No merge conflicts, no duplicate or competing components, no broken imports.
