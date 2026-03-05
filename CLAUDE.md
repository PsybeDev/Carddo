# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Carddo is a data-driven card game engine. The core game logic is written once in Rust (`ditto_engine/`) and compiled to two targets: a server-side Elixir NIF and a browser-side WASM module. The backend is Phoenix/Elixir; the frontend is SvelteKit.

## Commands

### Backend (run from `backend/`)
```bash
mix setup          # Install deps, create and migrate DB (first-time setup)
mix phx.server     # Start dev server at localhost:4000
mix test           # Run tests
mix test test/my_test.exs  # Run a single test file
mix test --failed  # Re-run only failed tests
mix precommit      # REQUIRED before finishing: compile, format check, test
```

### Frontend (run from `frontend/`)
```bash
pnpm i             # Install dependencies
pnpm run dev       # Start dev server at localhost:5173
pnpm run check     # Type-check (svelte-check + tsc)
pnpm run lint      # Prettier + ESLint check
pnpm run format    # Auto-format
pnpm run test:unit # Run Vitest unit tests
pnpm run test      # Run tests once (no watch)
```

### Rust Engine (run from `ditto_engine/`)
```bash
cargo build        # Build all crates
cargo test         # Run all tests
# WASM build (run from ditto_engine/ditto_wasm/):
wasm-pack build --target web   # Output goes to pkg/, imported by frontend
```

### Orchestration (root)
```bash
make setup         # Full one-time setup (WASM + Elixir + Node)
make build-wasm    # Rebuild WASM only
make dev           # Run backend + frontend in parallel
```

## Architecture

### Hybrid Validation Model
The game engine runs in two places simultaneously:
- **Client (WASM)**: `ditto_wasm` provides fast pre-flight `client_validate_move()` before sending to server
- **Server (NIF)**: `ditto_nif` provides definitive `process_move()` with full resolution

Both share identical validation logic from `ditto_core`. The frontend imports WASM directly from `../ditto_engine/ditto_wasm/pkg`.

### Game State Model (`ditto_core/src/state.rs`)
The engine is intentionally data-driven — no hardcoded game concepts like health or mana:
- **`GameState`**: Serializable to/from JSON; contains all entities, zones, event queue, pending animations, and state checks
- **`Entity`**: Has `properties: HashMap<String, i32>` for arbitrary stats; designers define keys
- **`Zone`**: Ordered list of entity IDs with visibility control (`Public | OwnerOnly | Hidden(count)`)
- **`Action`** (enum): The only way to mutate state — `MutateProperty`, `MoveEntity`, `SpawnEntity`, `EndTurn`
- **`Ability`**: Event-Condition-Action rules that trigger on `"on_before_*"` or `"on_after_*"` events; can cancel or queue new actions
- **`StateCheck`**: Designer-configured rules that auto-move entities when a property crosses a threshold (e.g., death)

### Resolution Pipeline (`ditto_core/src/engine.rs`)
1. `validate_action()` — pre-flight checks
2. Pop event from queue (FIFO default, or LIFO for MTG-style stack)
3. Run before-phase hooks (can cancel)
4. Execute action, record animations
5. Run after-phase hooks (can queue new events)
6. Run state checks
7. Bounded at 1,000 steps to guard against infinite hook loops

### Elixir Integration
`backend/lib/carddo/native.ex` exposes the NIF as `Carddo.Native.process_move/3`.

## Pre-commit Requirements

- **Backend**: Always run `mix precommit` — it compiles with `--warnings-as-errors`, checks unused deps, verifies formatting, and runs tests.
- **Frontend**: Run `pnpm run lint && pnpm run test` before finishing.

## Backend Conventions (from AGENTS.md)

- Use `:req` (`Req`) for HTTP — never `:httpoison`, `:tesla`, or `:httpc`
- LiveView templates must begin with `<Layouts.app flash={@flash} ...>`; always pass `current_scope`
- Use `<.input>` from `core_components.ex` for form inputs; use `<.icon>` for icons
- Never use map access syntax (`struct[:field]`) on Ecto structs — use `struct.field` or `Ecto.Changeset.get_field/2`
- Preload Ecto associations in queries before accessing them in templates
- Never nest multiple modules in the same file
- `Ecto.Schema` fields always use `:string` type even for text columns
- Fields set programmatically (like `user_id`) must not appear in `cast` calls

## Frontend Conventions (from AGENTS.md)

- Package manager: **pnpm**
- Use Svelte 5 rune syntax: `$state`, `$effect`, `$props`, `$derived`
- Code style: tabs (not spaces), single quotes, line width 100, Tailwind class sorting via Prettier plugin
- An MCP server provides Svelte 5 & SvelteKit docs — use `list-sections` then `get-documentation` for unfamiliar APIs; run `svelte-autofixer` before finalizing Svelte code
