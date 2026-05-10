# Research: AI Rules Lawyer & Playtester

## Decision: Rust-Python Bridge (PyO3)
- **Problem**: Need high-speed engine access from Python agents without HTTP overhead.
- **Solution**: Use `PyO3` to wrap `ditto_core`.
- **Implementation**: Create a new crate `ditto_sim` that provides a Python-compatible `GameContext`.
- **Data Exchange**: Pass `GameState` as a JSON string or serialized buffer to minimize mapping complexity in the first iteration.

## Decision: Agentic Loop (LangGraph)
- **Problem**: Gemini may suggest invalid moves that violate engine rules.
- **Solution**: Use `LangGraph` with a "Validation Loop". If `ditto_sim` returns an error for an action, the graph routes back to the "Player Node" with the error message as feedback.
- **Auditor**: A "Rules Lawyer" node will run at the end of every turn (or every move) to check for balance metrics (e.g. "player 1 has 10x more resources than player 2").

## Decision: Elixir-Python Integration
- **Problem**: Triggering Python from Phoenix asynchronously.
- **Solution**: Use **Oban**. The Oban worker will execute `python ai_playtester/src/main.py --params <json_params>`.
- **Result Handling**: Python will insert the `BalanceReport` directly into the Postgres database using the same connection string, or Elixir will parse the JSON output from the command and save it.
- **Choice**: Elixir will parse stdout JSON to maintain Elixir as the source of truth for DB writes.

## Decision: Subscription Gate
- **Problem**: Gating usage.
- **Solution**: Add `has_ai_audit_access: boolean` to the `User` schema (or a separate `FeatureFlag` table).
- **Backend**: Phoenix controller checks this flag before enqueuing the Oban job.
- **Frontend**: Hide/Disable the "Run Simulation" button if the flag is false, and show a "Upgrade" CTA.
