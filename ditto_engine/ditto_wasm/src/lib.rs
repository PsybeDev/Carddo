use wasm_bindgen::prelude::*;
use ditto_core::{Action, GameState, validate_action};

#[wasm_bindgen]
pub fn client_validate_move(state_json: JsValue, action_json: JsValue) -> Result<(), JsValue> {
    let state: GameState = serde_wasm_bindgen::from_value(state_json)
        .map_err(|e| JsValue::from_str(&format!("invalid state: {e}")))?;
    let action: Action = serde_wasm_bindgen::from_value(action_json)
        .map_err(|e| JsValue::from_str(&format!("invalid action: {e}")))?;
    validate_action(&state, &action).map_err(|e| JsValue::from_str(&e))
}

#[cfg(test)]
mod tests {
    use ditto_core::{validate_action, Action, Entity, GameState, Visibility, Zone};
    use std::collections::HashMap;

    fn make_state() -> GameState {
        let entity = Entity {
            id: "card1".to_string(),
            owner_id: "p1".to_string(),
            template_id: "t1".to_string(),
            properties: HashMap::new(),
            abilities: vec![],
        };
        let hand = Zone {
            id: "hand".to_string(),
            owner_id: Some("p1".to_string()),
            visibility: Visibility::OwnerOnly,
            entities: vec!["card1".to_string()],
        };
        let board = Zone {
            id: "board".to_string(),
            owner_id: None,
            visibility: Visibility::Public,
            entities: vec![],
        };
        GameState {
            entities: HashMap::from([("card1".to_string(), entity)]),
            zones: HashMap::from([
                ("hand".to_string(), hand),
                ("board".to_string(), board),
            ]),
            ..GameState::new()
        }
    }

    #[test]
    fn valid_move() {
        let state = make_state();
        let action = Action::MoveEntity {
            entity_id: "card1".to_string(),
            from_zone: "hand".to_string(),
            to_zone: "board".to_string(),
            index: None,
        };
        assert!(validate_action(&state, &action).is_ok());
    }

    #[test]
    fn entity_not_in_source_zone() {
        let state = make_state();
        let action = Action::MoveEntity {
            entity_id: "card1".to_string(),
            from_zone: "board".to_string(), // card1 is in hand
            to_zone: "hand".to_string(),
            index: None,
        };
        assert!(validate_action(&state, &action).is_err());
    }

    #[test]
    fn missing_dest_zone() {
        let state = make_state();
        let action = Action::MoveEntity {
            entity_id: "card1".to_string(),
            from_zone: "hand".to_string(),
            to_zone: "graveyard".to_string(), // not in client state
            index: None,
        };
        assert!(validate_action(&state, &action).is_err());
    }

    #[test]
    fn mutate_unknown_entity() {
        let state = make_state();
        let action = Action::MutateProperty {
            target_id: "ghost".to_string(),
            property: "health".to_string(),
            delta: -1,
        };
        assert!(validate_action(&state, &action).is_err());
    }

    #[test]
    fn end_turn_always_ok() {
        let state = make_state();
        assert!(validate_action(&state, &Action::EndTurn).is_ok());
    }

    #[test]
    fn move_entity_not_in_entities_map() {
        let mut state = make_state();
        // Inject a dangling zone reference: zone lists an ID that isn't in state.entities
        state.zones.get_mut("hand").unwrap().entities.push("ghost".to_string());
        let action = Action::MoveEntity {
            entity_id: "ghost".to_string(),
            from_zone: "hand".to_string(),
            to_zone: "board".to_string(),
            index: None,
        };
        assert!(validate_action(&state, &action).is_err());
    }

    #[test]
    fn spawn_duplicate_entity() {
        let state = make_state();
        // card1 already exists in state.entities
        let action = Action::SpawnEntity {
            entity: ditto_core::Entity {
                id: "card1".to_string(),
                owner_id: "p1".to_string(),
                template_id: "t1".to_string(),
                properties: std::collections::HashMap::new(),
                abilities: vec![],
            },
            zone_id: "board".to_string(),
        };
        assert!(validate_action(&state, &action).is_err());
    }

    #[test]
    fn spawn_entity_already_in_zone_entities_list() {
        let mut state = make_state();
        // Dangling zone reference: zone lists an ID not in state.entities
        state.zones.get_mut("board").unwrap().entities.push("ghost".to_string());
        let action = Action::SpawnEntity {
            entity: ditto_core::Entity {
                id: "ghost".to_string(),
                owner_id: "p1".to_string(),
                template_id: "t1".to_string(),
                properties: std::collections::HashMap::new(),
                abilities: vec![],
            },
            zone_id: "board".to_string(),
        };
        assert!(validate_action(&state, &action).is_err());
    }
}
