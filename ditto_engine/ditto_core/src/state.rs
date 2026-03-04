use serde::{Deserialize, Serialize};
use std::collections::{HashMap, VecDeque};

// ==========================================
// 1. THE GAME STATE
// ==========================================

/// Controls the resolution order of the event queue.
///
/// - `Fifo` (default): first-in, first-out — suited for games like Hearthstone
///   where actions resolve in the order they were queued.
/// - `Lifo`: last-in, first-out (a stack) — suited for games like MTG where the
///   most recently added spell or ability resolves first.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub enum StackOrder {
    #[default]
    Fifo,
    Lifo,
}

/// The master struct. This is the exact payload that Elixir stores in memory
/// and Svelte receives over WebSockets.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameState {
    /// Every card, player, and token in the game, indexed by a unique UUID.
    pub entities: HashMap<String, Entity>,

    /// The physical/logical areas of the game (e.g., "player_1_hand", "graveyard").
    pub zones: HashMap<String, Zone>,

    /// The chronological list of events waiting to be executed.
    pub event_queue: VecDeque<Event>,

    /// A log of visual updates for Svelte to animate (e.g., "-3 Health").
    /// This is wiped clean at the end of every network tick.
    pub pending_animations: Vec<Animation>,

    /// Determines whether events resolve in FIFO or LIFO (stack) order.
    /// Defaults to `Fifo`. Set to `Lifo` for MTG-style stack semantics.
    #[serde(default)]
    pub stack_order: StackOrder,

    /// Rules evaluated after every action to detect and respond to game-over conditions.
    /// Replaces hardcoded "health <= 0 → graveyard" logic. Configure per game:
    ///
    /// ```ignore
    /// state.state_checks.push(StateCheck {
    ///     watch_property: "health".into(),
    ///     operator: "<=".into(),
    ///     threshold: 0,
    ///     move_to_zone: "graveyard".into(),
    /// });
    /// ```
    #[serde(default)]
    pub state_checks: Vec<StateCheck>,
}

impl GameState {
    pub fn new() -> Self {
        Self {
            entities: HashMap::new(),
            zones: HashMap::new(),
            event_queue: VecDeque::new(),
            pending_animations: Vec::new(),
            stack_order: StackOrder::Fifo,
            state_checks: Vec::new(),
        }
    }
}

impl Default for GameState {
    fn default() -> Self {
        Self::new()
    }
}

// ==========================================
// 2. THE BUILDING BLOCKS
// ==========================================

/// A completely abstract object. It has no hardcoded rules.
/// If it's a Magic card, it might have {"mana_cost": 3}.
/// If it's a Pokémon, it might have {"hp": 120}.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Entity {
    pub id: String,
    pub owner_id: String,
    pub template_id: String,

    /// The dynamic stats of the entity. Keys are arbitrary strings defined
    /// by the game designer, not the engine.
    pub properties: HashMap<String, i32>,

    /// The custom rules attached to this specific entity.
    pub abilities: Vec<Ability>,
}

/// A container for entities.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Zone {
    pub id: String,
    pub owner_id: Option<String>,

    /// Determines if Svelte is allowed to see the entities inside.
    pub visibility: Visibility,

    /// The ordered list of entity UUIDs currently residing here.
    pub entities: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Visibility {
    Public,          // Everyone sees the cards (e.g., The Board)
    OwnerOnly,       // Only the owner sees them (e.g., A Player's Hand)
    Hidden(usize),   // No one sees them, just a count (e.g., A Deck)
}

// ==========================================
// 3. STATE CHECKS
// ==========================================

/// A designer-configured rule evaluated after every action.
///
/// Instead of hardcoding "health <= 0 → move to graveyard", the engine
/// holds a list of these and applies them generically. This lets any game
/// define its own death conditions and destination zones.
///
/// Example — MTG:  `{ watch_property: "toughness", operator: "<=", threshold: 0, move_to_zone: "graveyard" }`
/// Example — Pokémon: `{ watch_property: "hp", operator: "<=", threshold: 0, move_to_zone: "discard_pile" }`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StateCheck {
    /// The entity property to inspect (e.g. `"health"`, `"toughness"`).
    pub watch_property: String,
    /// Comparison operator: `"<="`, `"<"`, `"=="`, `">"`, `">="`, `"!="`.
    pub operator: String,
    /// The value to compare against (e.g. `0`).
    pub threshold: i32,
    /// The zone entities satisfying the condition are moved to.
    pub move_to_zone: String,
}

// ==========================================
// 4. THE RULES ENGINE (ECA)
// ==========================================

/// The Event-Condition-Action definition built by the designer in Svelte.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Ability {
    pub id: String,
    pub name: String,
    /// Trigger format: `"on_before_<action_type>"` or `"on_after_<action_type>"`.
    /// Append `:self` to restrict to events that target the ability's owner entity.
    /// Use `"on_before_any"` / `"on_after_any"` to match every action of that phase.
    pub trigger: String,
    pub conditions: Vec<Condition>,
    pub actions: Vec<Action>,
    /// If `true` and this is a before-phase hook, the triggering event is dropped.
    #[serde(default)]
    pub cancels: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Condition {
    pub target: String,
    pub property: String,
    pub operator: String,
    pub value: i32,
}

// ==========================================
// 5. THE EVENT QUEUE ACTIONS
// ==========================================

/// The wrapper that gives context to an action waiting in the queue.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Event {
    pub source_id: String,
    pub action: Action,
}

/// The ONLY ways the game state is allowed to change.
/// By restricting mutations to these enums, the engine remains perfectly predictable.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Action {
    MutateProperty {
        target_id: String,
        property: String,
        delta: i32,
    },
    MoveEntity {
        entity_id: String,
        from_zone: String,
        to_zone: String,
        index: Option<usize>,
    },
    SpawnEntity {
        entity: Entity,
        zone_id: String,
    },
    EndTurn,
}

// ==========================================
// 6. THE FRONTEND FEEDBACK
// ==========================================

/// Instructions sent back to Svelte to make the game look good.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Animation {
    FloatText {
        target_id: String,
        text: String,
        color: String,
    },
    PlayEffect {
        target_id: String,
        effect_name: String,
    },
}

// ==========================================
// 7. TESTS
// ==========================================

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entity(id: &str, props: Vec<(&str, i32)>) -> Entity {
        Entity {
            id: id.to_string(),
            owner_id: "player_1".to_string(),
            template_id: "card_template_001".to_string(),
            properties: props.into_iter().map(|(k, v)| (k.to_string(), v)).collect(),
            abilities: vec![],
        }
    }

    #[test]
    fn gamestate_serializes_and_deserializes_roundtrip() {
        let mut state = GameState::new();

        let entity = make_entity("entity_001", vec![("health", 20), ("attack", 5)]);
        state.entities.insert(entity.id.clone(), entity);

        state.zones.insert(
            "battlefield".to_string(),
            Zone {
                id: "battlefield".to_string(),
                owner_id: None,
                visibility: Visibility::Public,
                entities: vec!["entity_001".to_string()],
            },
        );

        state.event_queue.push_back(Event {
            source_id: "player_1".to_string(),
            action: Action::MutateProperty {
                target_id: "entity_001".to_string(),
                property: "health".to_string(),
                delta: -3,
            },
        });

        let json = serde_json::to_string(&state).expect("serialization failed");
        let restored: GameState = serde_json::from_str(&json).expect("deserialization failed");

        assert!(restored.entities.contains_key("entity_001"));
        assert_eq!(restored.entities["entity_001"].properties["health"], 20);
        assert_eq!(restored.zones["battlefield"].visibility, Visibility::Public);
        assert_eq!(restored.event_queue.len(), 1);
    }

    #[test]
    fn entity_supports_arbitrary_property_keys() {
        // MTG-style entity
        let mtg_card = make_entity(
            "mtg_001",
            vec![("power", 3), ("toughness", 4), ("mana_cost", 2)],
        );
        assert_eq!(mtg_card.properties["power"], 3);
        assert_eq!(mtg_card.properties["toughness"], 4);

        // Pokémon-style entity
        let pokemon = make_entity(
            "poke_001",
            vec![("hp", 120), ("stage", 1), ("retreat_cost", 2)],
        );
        assert_eq!(pokemon.properties["hp"], 120);
        assert_eq!(pokemon.properties["retreat_cost"], 2);

        // Flesh and Blood-style entity
        let fab_card = make_entity(
            "fab_001",
            vec![("attack", 4), ("defense", 3), ("intellect", 4)],
        );
        assert_eq!(fab_card.properties["intellect"], 4);

        // Engine has no knowledge of what these keys mean — purely data-driven
        let json = serde_json::to_string(&fab_card).expect("serialization failed");
        let restored: Entity = serde_json::from_str(&json).expect("deserialization failed");
        assert_eq!(restored.properties["attack"], 4);
    }

    #[test]
    fn spawn_entity_action_serializes() {
        let entity = make_entity("token_001", vec![("power", 1), ("toughness", 1)]);
        let event = Event {
            source_id: "player_1".to_string(),
            action: Action::SpawnEntity {
                entity,
                zone_id: "battlefield".to_string(),
            },
        };

        let json = serde_json::to_string(&event).expect("serialization failed");
        let restored: Event = serde_json::from_str(&json).expect("deserialization failed");

        assert_eq!(event, restored);
    }

    #[test]
    fn visibility_hidden_roundtrip() {
        let zone = Zone {
            id: "deck".to_string(),
            owner_id: Some("player_1".to_string()),
            visibility: Visibility::Hidden(40),
            entities: vec![],
        };

        let json = serde_json::to_string(&zone).expect("serialization failed");
        let restored: Zone = serde_json::from_str(&json).expect("deserialization failed");

        assert_eq!(restored.visibility, Visibility::Hidden(40));
    }
}
