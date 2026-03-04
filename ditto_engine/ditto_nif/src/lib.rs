use ditto_core::{validate_action, Action, Event, GameState};
use rustler::{Atom, NifResult};

/// Maximum number of events `resolve_queue_bounded` will process per NIF call.
/// Prevents runaway hook chains from monopolising dirty schedulers.
const MAX_RESOLUTION_STEPS: usize = 1_000;

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn process_move(
    state_json: String,
    action_json: String,
    player_id: String,
) -> NifResult<(Atom, String, String)> {
    let mut state: GameState = match serde_json::from_str(&state_json) {
        Ok(s) => s,
        Err(e) => return Ok((atoms::error(), format!("invalid state: {e}"), "[]".to_string())),
    };

    state.pending_animations.clear();

    let action: Action = match serde_json::from_str(&action_json) {
        Ok(a) => a,
        Err(e) => return Ok((atoms::error(), format!("invalid action: {e}"), "[]".to_string())),
    };

    if let Err(reason) = validate_action(&state, &action) {
        return Ok((atoms::error(), reason, "[]".to_string()));
    }

    state.event_queue.push_back(Event {
        source_id: player_id,
        action,
    });

    if let Err(reason) = state.resolve_queue_bounded(MAX_RESOLUTION_STEPS) {
        return Ok((atoms::error(), reason, "[]".to_string()));
    }

    let animations = std::mem::take(&mut state.pending_animations);

    let new_state_json = match serde_json::to_string(&state) {
        Ok(s) => s,
        Err(e) => {
            return Ok((
                atoms::error(),
                format!("state serialization failed: {e}"),
                "[]".to_string(),
            ))
        }
    };

    let animations_json = match serde_json::to_string(&animations) {
        Ok(s) => s,
        Err(e) => {
            return Ok((
                atoms::error(),
                format!("animation serialization failed: {e}"),
                "[]".to_string(),
            ))
        }
    };

    Ok((atoms::ok(), new_state_json, animations_json))
}

rustler::init!("Elixir.Carddo.Native");
