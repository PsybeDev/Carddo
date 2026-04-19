use ditto_core::{validate_action, Action, Event, GameState};
use rustler::{Atom, NifResult};

/// Maximum number of events `resolve_queue_bounded` will process per NIF call.
/// Prevents runaway hook chains from monopolising dirty schedulers.
const MAX_RESOLUTION_STEPS: usize = 1_000;

const EMPTY_ANIMATIONS_JSON: &str = "[]";

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

#[inline]
fn err(reason: String) -> NifResult<(Atom, String, String)> {
    Ok((atoms::error(), reason, EMPTY_ANIMATIONS_JSON.to_string()))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn process_move(
    state_json: String,
    action_json: String,
    player_id: String,
) -> NifResult<(Atom, String, String)> {
    let mut state: GameState = match serde_json::from_str(&state_json) {
        Ok(s) => s,
        Err(e) => return err(format!("invalid state: {e}")),
    };

    state.pending_animations.clear();

    let action: Action = match serde_json::from_str(&action_json) {
        Ok(a) => a,
        Err(e) => return err(format!("invalid action: {e}")),
    };

    if let Err(reason) = validate_action(&state, &action) {
        return err(reason);
    }

    state.event_queue.push_back(Event {
        source_id: player_id,
        action,
    });

    if let Err(reason) = state.resolve_queue_bounded(MAX_RESOLUTION_STEPS) {
        return err(reason);
    }

    let animations = std::mem::take(&mut state.pending_animations);

    let new_state_json = match serde_json::to_string(&state) {
        Ok(s) => s,
        Err(e) => return err(format!("state serialization failed: {e}")),
    };

    let animations_json = match serde_json::to_string(&animations) {
        Ok(s) => s,
        Err(e) => return err(format!("animation serialization failed: {e}")),
    };

    Ok((atoms::ok(), new_state_json, animations_json))
}

#[inline]
fn enum_err(reason: String) -> NifResult<(Atom, String)> {
    Ok((atoms::error(), reason))
}

/// Returns every currently-legal `Action` that `player_id` could submit, as a
/// JSON-encoded array. Used by the server-side AI in `GameRoom` (CAR-46).
///
/// Success shape: `{:ok, "[\"EndTurn\", {\"MoveEntity\": {...}}]"}`.
/// Error shape:   `{:error, reason_string}`.
#[rustler::nif(schedule = "DirtyCpu")]
fn valid_actions_for_player(
    state_json: String,
    player_id: String,
) -> NifResult<(Atom, String)> {
    let state: GameState = match serde_json::from_str(&state_json) {
        Ok(s) => s,
        Err(e) => return enum_err(format!("invalid state: {e}")),
    };

    let actions = ditto_core::valid_actions_for_player(&state, &player_id);

    match serde_json::to_string(&actions) {
        Ok(json) => Ok((atoms::ok(), json)),
        Err(e) => enum_err(format!("actions serialization failed: {e}")),
    }
}

rustler::init!("Elixir.Carddo.Native");
