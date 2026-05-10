# Feature Specification: AI Rules Lawyer & Playtester

**Feature Branch**: `001-ai-rules-lawyer-playtester`  
**Created**: Saturday, May 9, 2026  
**Status**: Draft  
**Input**: User description: "Role: Senior Technical Product Manager & Software Architect Task: Create a Linear Project and a series of Spec-Driven Development (SDD) issues for the \"Carddo\" repository. Project Context: We are building an AI Rules Lawyer & Playtester for Carddo (a TCG engine). Engine: Rust (ECA-based logic). Backend: Elixir/Phoenix (using NIFs for the engine). Frontend: Svelte (using WASM). AI Architecture: LangGraph (Python) driving the Rust engine via PyO3 bindings. LLM: Gemini 1.5 Flash (Cost-effective logic/simulation). Monetization: Gated behind a subscription feature flag."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Designer Triggers AI Playtest (Priority: P1)

As a Game Designer, I want to trigger an automated playtest of a card set using AI agents so that I can identify balance issues and infinite loops without manual testing.

**Why this priority**: Core value proposition. Automated testing is the primary driver for this feature.

**Independent Test**: Can be tested by invoking the simulation worker with a specific card set and verifying that a `BalanceReport` is generated.

**Acceptance Scenarios**:

1. **Given** a valid card set version, **When** I trigger the AI Playtester, **Then** an asynchronous simulation starts.
2. **Given** an active simulation, **When** two AI agents (Gemini 1.5 Flash) play against each other, **Then** every move is validated by the Rust engine.
3. **Given** an invalid move suggested by an AI agent, **When** the Rust engine rejects it, **Then** the LangGraph loop provides feedback and forces the agent to re-think its move.

...

- **FR-005**: LangGraph MUST use Gemini 1.5 Flash for player nodes.


As a Game Designer, I want an automated auditor to monitor the simulation for technical or balance anomalies so that I don't have to manually review thousands of logs.

**Why this priority**: Essential for identifying the "Problematic Cards" and protecting system integrity (e.g. preventing infinite simulations).

**Independent Test**: Can be tested by seeding a simulation state with a known anomaly (e.g. infinite loop) and verifying the auditor halts the simulation and flags it.

**Acceptance Scenarios**:

1. **Given** a simulation exceeds 50 turns, **When** the Rules Lawyer node checks the state, **Then** the simulation is halted and marked as a potential infinite loop.
2. **Given** a resource generation spike or integer overflow, **When** the auditor monitors the state, **Then** the anomaly is recorded in the final BalanceReport.

---

### User Story 3 - View Balance Reports (Priority: P2)

As a Game Designer, I want to view historical balance reports in a dashboard so that I can track how balance changes over time as I tune the cards.

**Why this priority**: Enables the iterative design loop.

**Independent Test**: Can be tested by navigating to the Simulation Dashboard and verifying historical reports are listed and expandable.

**Acceptance Scenarios**:

1. **Given** completed simulations, **When** I view the Simulation Dashboard, **Then** I see a list of reports with timestamps and card set versions.
2. **Given** a specific report, **When** I open the viewer, **Then** I see highlighted "Problematic Cards" and win rate statistics.

---

### User Story 4 - Subscription Gating (Priority: P3)

As a Product Manager, I want to restrict the AI Playtester to subscribed users so that the feature can be monetized to cover LLM costs.

**Why this priority**: Necessary for business sustainability given the costs of Gemini 3.5 Pro API usage.

**Independent Test**: Can be tested by attempting to trigger a simulation with a user account that lacks the `has_ai_audit_access` flag.

**Acceptance Scenarios**:

1. **Given** a user without a subscription, **When** they attempt to trigger a simulation, **Then** the system returns a 402 Payment Required error.
2. **Given** a subscribed user, **When** they trigger a simulation, **Then** the request is authorized and processed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide Python bindings (PyO3) for the core Rust ECA engine (`carddo_sim`).
- **FR-002**: Python module MUST expose a `GameContext` that accepts `AgentAction` JSON and returns `SimulationState` JSON.
- **FR-003**: System MUST define shared schemas (JSON/Protobuf) for `BalanceReport` and `SimulationState`.
- **FR-004**: System MUST implement a stateful LangGraph in Python for orchestrating AI playtests.
- **FR-005**: LangGraph MUST use Gemini 3.5 Pro for player nodes.
- **FR-006**: System MUST include a "Rules Lawyer" node to detect anomalies (turn counts, resource spikes, overflows).
- **FR-007**: Elixir backend MUST implement a subscription gate (`has_ai_audit_access` feature flag).
- **FR-008**: System MUST store `BalanceReport` results in a Postgres database via Ecto.
- **FR-009**: System MUST use Oban to process simulations asynchronously.
- **FR-010**: Frontend (Svelte) MUST provide a dashboard for triggering simulations and viewing historical reports.

### Key Entities *(include if feature involves data)*

- **BalanceReport**: Data structure containing win rates, identified anomalies, infinite loop flags, and card set version.
- **SimulationState**: Snapshots of the game engine state during playtesting.
- **AgentAction**: Intent sent from AI players to the simulation engine.
- **SubscriptionGate**: Logic controlling access based on user feature flags.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Simulations of 100 turns complete in under 60 seconds (excluding LLM latency).
- **SC-002**: 100% of simulated infinite loops (as defined by turn count > 50) are successfully identified and flagged.
- **SC-003**: Subscription gate blocks 100% of simulation triggers from unauthorized users.
- **SC-004**: System successfully recovers from "Invalid Move" LLM output in 100% of cases within 3 retries.

## Assumptions

- **Assumption 1**: Gemini 3.5 Pro provides sufficient reasoning for basic TCG gameplay and balance identification.
- **Assumption 2**: The Rust engine is stable enough to be wrapped in PyO3 without major refactoring.
- **Assumption 3**: Users will primarily use the dashboard via desktop browsers (Svelte).
- **Assumption 4**: The volume of simulation requests can be handled by the existing Oban queue configuration.
- **Assumption 5**: AI agents can be configured to have either perfect information (full GameState) or hidden information (Fog of War) depending on the simulation parameters.
