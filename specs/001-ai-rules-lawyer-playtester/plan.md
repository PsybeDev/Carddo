# Implementation Plan: AI Rules Lawyer & Playtester

**Branch**: `001-ai-rules-lawyer-playtester` | **Date**: Saturday, May 9, 2026 | **Spec**: [specs/001-ai-rules-lawyer-playtester/spec.md](spec.md)
**Input**: Feature specification from `/specs/001-ai-rules-lawyer-playtester/spec.md`

## Summary

Implement an automated AI-driven playtesting and rules auditing system for the Carddo TCG engine. The implementation details, research findings, and specific tasks are tracked as SDD (Spec-Driven Development) issues in the "AI Rules Lawyer & Playtester" Linear project.

**Linear Project**: [AI Rules Lawyer & Playtester](https://linear.app/carddo/project/ai-rules-lawyer-and-playtester-22bfb69f5c9b)

## Key Deliverables (Linear Issues)

- **Engine Bindings**: [CAR-73](https://linear.app/carddo/issue/CAR-73) - PyO3 bindings for `carddo_sim`.
- **AI Orchestration**: [CAR-78](https://linear.app/carddo/issue/CAR-78) - LangGraph Playtester Loop.
- **Rules Auditor**: [CAR-80](https://linear.app/carddo/issue/CAR-80) - Rules Lawyer Node.
- **Backend Jobs**: [CAR-79](https://linear.app/carddo/issue/CAR-79) - Async Simulation Worker (Oban).
- **Monetization**: [CAR-74](https://linear.app/carddo/issue/CAR-74) - Subscription Gate.
- **Frontend Dashboard**: [CAR-77](https://linear.app/carddo/issue/CAR-77) - Svelte Dashboard & Report Viewer.

## Technical Context

**Language/Version**: Rust 1.75+, Python 3.11+, Elixir 1.15+, TypeScript (Svelte 5)  
**Primary Dependencies**: PyO3, LangGraph, Google AI Python SDK (Gemini 1.5 Flash), Phoenix, Ecto, Oban  
**Storage**: PostgreSQL (Historical Balance Reports)  
**Testing**: cargo test (Rust), pytest (Python), mix test (Elixir), vitest (Svelte)  
**Target Platform**: Linux (Docker/Fly.io)
**Project Type**: Hybrid Web Service / Engine / AI Orchestration  
**Performance Goals**: 100 turns < 60s (excluding LLM latency)  
**Constraints**: Gated by subscription feature flag; avoid HTTP overhead in simulation loop.
**Scale/Scope**: Support simulation of complex card interactions across thousands of turns.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Library-First**: Core logic remains in `ditto_core`. `ditto_sim` is a self-contained binding layer.
- [x] **CLI/Text Interface**: Python LangGraph uses JSON for all state transitions and reports.
- [x] **Test-First**: Implementation will follow TDD for schemas and engine bindings.
- [x] **Integration Testing**: Oban-to-Python and Python-to-Rust contracts require strict validation.
- [x] **Simplicity**: Gemini 1.5 Flash chosen for cost-effectiveness and sufficient reasoning for MVP.

## Project Structure

### Documentation (this feature)

```text
specs/001-ai-rules-lawyer-playtester/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
ditto_engine/
├── ditto_core/          # Existing: Core Rust ECA logic
└── ditto_sim/           # NEW: PyO3 bindings for simulation

ai_playtester/           # NEW: Python LangGraph orchestration
├── src/
│   ├── graph.py         # LangGraph definition
│   ├── nodes/           # Player and Auditor nodes
│   └── schemas/         # JSON/Protobuf definitions
├── tests/
└── requirements.txt

backend/                 # Existing: Phoenix/Elixir
├── lib/carddo/
│   ├── ai_playtest/     # NEW: Ecto schemas and Oban jobs
│   └── subscription/    # NEW: Feature flag logic
└── priv/repo/migrations/

frontend/                # Existing: Svelte
└── src/routes/admin/
    └── simulation/      # NEW: Dashboard and Report Viewer
```

**Structure Decision**: Multi-repo/Multi-component layout. Python orchestration is kept in a separate top-level directory `ai_playtester` to manage its own environment, while `ditto_sim` lives alongside the engine crates.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Cross-language (Rust-Python) | High-speed simulation requirement | Python-only engine would require re-implementing logic; HTTP bridge is too slow. |
| Agentic Workflow (LangGraph) | Complex "Invalid Move" recovery | Simple LLM calls can't handle multi-step stateful corrections easily. |
