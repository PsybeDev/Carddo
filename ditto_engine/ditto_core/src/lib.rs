use serde::{Deserialize, Serialize};
use std::collections::{HashMap, VecDeque};

// ==========================================
// 1. THE GAME STATE
// ==========================================

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
}

impl GameState {
    pub fn new() -> Self {
        Self {
            entities: HashMap::new(),
            zones: HashMap::new(),
            event_queue: VecDeque::new(),
            pending_animations: Vec::new(),
        }
    }
}

// ==========================================
// 2. THE BUILDING BLOCKS
// ==========================================

/// A completely abstract object. It has no hardcoded rules.
/// If it's a Magic card, it might have {"mana_cost": 3}. 
/// If it's a Pokémon, it might have {"hp": 120}.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entity {
    pub id: String,
    pub owner_id: String,
    pub template_id: String, // References the designer's original card ID
    
    /// The dynamic stats of the entity.
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
    Public,              // Everyone sees the cards (e.g., The Board)
    OwnerOnly,           // Only the owner sees them (e.g., A Player's Hand)
    Hidden(usize),       // No one sees them, just a count (e.g., A Deck)
}

// ==========================================
// 3. THE RULES ENGINE (ECA)
// ==========================================

/// The Event-Condition-Action definition built by the designer in Svelte.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ability {
    pub id: String,
    pub name: String,
    pub trigger: String, // e.g., "on_play", "on_turn_start", "on_before_damage"
    pub conditions: Vec<Condition>,
    pub actions: Vec<Action>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Condition {
    pub target: String,   // e.g., "self", "event_target", "event_source"
    pub property: String, // e.g., "health"
    pub operator: String, // e.g., "gte", "eq", "lt"
    pub value: i32,
}

// ==========================================
// 4. THE EVENT QUEUE ACTIONS
// ==========================================

/// The wrapper that gives context to an action waiting in the queue.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub source_id: String, // The entity or player that caused this
    pub action: Action,
}

/// The ONLY ways the game state is allowed to change.
/// By restricting mutations to these enums, the engine remains perfectly predictable.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Action {
    MutateProperty {
        target_id: String,
        property: String, // e.g., "health"
        delta: i32,       // e.g., -5
    },
    MoveEntity {
        entity_id: String,
        from_zone: String,
        to_zone: String,
        index: Option<usize>, // For specific ordering, like top/bottom of deck
    },
    EndTurn,
}

// ==========================================
// 5. THE FRONTEND FEEDBACK
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
        effect_name: String, // e.g., "explosion", "heal_sparkles"
    },
}
