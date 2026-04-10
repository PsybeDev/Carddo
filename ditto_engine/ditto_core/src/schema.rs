// ditto_core schema v0.1.0
//
// Single canonical source of truth for all types exchanged between the
// ditto_core engine and the SvelteKit frontend.
//
// Generated output: frontend/src/lib/types/ditto.generated.ts
// Re-generate:      make generate-types
// Source structs:   ditto_engine/ditto_core/src/state.rs

#[cfg(feature = "ts")]
pub fn generate_typescript() -> String {
    use crate::state::*;
    use ts_rs::{Config, TS};

    let cfg = Config::default();
    let header = "// ditto_core schema v0.1.0\n\
                  // AUTO-GENERATED — do not edit manually.\n\
                  // Re-generate: make generate-types\n\
                  // Source: ditto_engine/ditto_core/src/state.rs\n";

    let decls = [
        StackOrder::decl(&cfg),
        Visibility::decl(&cfg),
        StateCheck::decl(&cfg),
        Condition::decl(&cfg),
        Ability::decl(&cfg),
        GameOverInfo::decl(&cfg),
        Action::decl(&cfg),
        Animation::decl(&cfg),
        Entity::decl(&cfg),
        Zone::decl(&cfg),
        Event::decl(&cfg),
        GameState::decl(&cfg),
    ]
    .map(|d| format!("export {d}"));

    format!("{}\n{}\n", header, decls.join("\n\n"))
}
