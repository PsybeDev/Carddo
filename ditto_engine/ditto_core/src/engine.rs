use crate::state::{Action, Animation, Condition, Event, GameState, StackOrder, StateCheck};

// ==========================================
// VALIDATION
// ==========================================

pub fn validate_action(state: &GameState, action: &Action) -> Result<(), String> {
    match action {
        Action::MoveEntity { entity_id, from_zone, to_zone, .. } => {
            let src = state.zones.get(from_zone)
                .ok_or_else(|| format!("source zone '{}' not found", from_zone))?;
            if !state.zones.contains_key(to_zone) {
                return Err(format!("destination zone '{}' not found", to_zone));
            }
            if !src.entities.contains(entity_id) {
                return Err(format!("entity '{}' not in zone '{}'", entity_id, from_zone));
            }
            if !state.entities.contains_key(entity_id) {
                return Err(format!("entity '{}' not found in state", entity_id));
            }
            Ok(())
        }
        Action::MutateProperty { target_id, .. } => {
            state.entities.contains_key(target_id)
                .then_some(())
                .ok_or_else(|| format!("entity '{}' not found", target_id))
        }
        Action::SpawnEntity { zone_id, entity } => {
            let zone = state.zones.get(zone_id)
                .ok_or_else(|| format!("zone '{}' not found", zone_id))?;
            if state.entities.contains_key(&entity.id) {
                return Err(format!("entity '{}' already exists", entity.id));
            }
            if zone.entities.contains(&entity.id) {
                return Err(format!("entity '{}' already present in zone '{}'", entity.id, zone_id));
            }
            Ok(())
        }
        Action::EndTurn => Ok(()),
    }
}

// ==========================================
// HOOK PHASE
// ==========================================

#[derive(PartialEq)]
enum HookPhase {
    Before,
    After,
}

// ==========================================
// RESOLVE QUEUE
// ==========================================

impl GameState {
    /// Drains the event queue, resolving each event according to `stack_order`.
    ///
    /// - `StackOrder::Fifo` (default): first-in, first-out.
    /// - `StackOrder::Lifo`: last-in, first-out (MTG-style stack).
    ///
    /// For every event the loop:
    /// 1. Runs before-phase hooks (any hook with `cancels: true` drops the event).
    /// 2. Executes the action and records animations.
    /// 3. Runs after-phase hooks (may push new events onto the queue).
    /// 4. Runs state checks (e.g., death detection).
    pub fn resolve_queue(&mut self) {
        let _ = self.resolve_queue_impl(None);
    }

    /// Like [`resolve_queue`] but stops after processing `max_steps` events and returns `Err`
    /// if the queue still contains work at that point, guarding against runaway hook chains.
    pub fn resolve_queue_bounded(&mut self, max_steps: usize) -> Result<(), String> {
        self.resolve_queue_impl(Some(max_steps))
    }

    fn resolve_queue_impl(&mut self, max_steps: Option<usize>) -> Result<(), String> {
        let order = self.stack_order;
        let mut steps = 0;
        loop {
            if let Some(limit) = max_steps {
                if steps >= limit && !self.event_queue.is_empty() {
                    return Err(format!("resolution limit exceeded ({limit} steps)"));
                }
            }

            let Some(event) = (match order {
                StackOrder::Fifo => self.event_queue.pop_front(),
                StackOrder::Lifo => self.event_queue.pop_back(),
            }) else {
                break;
            };

            steps += 1;

            if self.run_hooks(HookPhase::Before, &event) {
                continue; // event was canceled
            }

            self.execute_action(&event);
            self.run_hooks(HookPhase::After, &event);
            self.run_state_checks();
        }
        Ok(())
    }

    // ==========================================
    // HOOK EVALUATION
    // ==========================================

    /// Scans all entity abilities for triggers that match the current event phase,
    /// evaluates their conditions, and pushes their actions onto the queue.
    ///
    /// Hook-triggered events are pushed to the "top" of the queue so they resolve
    /// before previously queued events — `push_front` for FIFO, `push_back` for LIFO.
    ///
    /// **Known limitation — before-hooks are not truly pre-execution:**
    /// The generated events of a non-canceling `on_before_*` hook are queued but only
    /// resolve *after* `execute_action` runs for the triggering event in the same
    /// iteration. Only `cancels: true` reliably prevents execution. Proper
    /// pre-execution interruption (e.g. MTG replacement effects) requires re-queueing
    /// the original event behind the hook events, which is a larger architectural
    /// change deferred to a follow-up.
    ///
    /// Returns `true` if any before-phase hook has `cancels: true` and its conditions pass.
    fn run_hooks(&mut self, phase: HookPhase, event: &Event) -> bool {
        let phase_prefix = match phase {
            HookPhase::Before => "on_before_",
            HookPhase::After => "on_after_",
        };
        let action_str = action_type_str(&event.action);
        let order = self.stack_order;

        // Clone and sort entity IDs so hook firing order is deterministic across runs.
        // HashMap iteration is non-deterministic; sorting by ID gives a stable order.
        let mut entity_ids: Vec<String> = self.entities.keys().cloned().collect();
        entity_ids.sort();

        let mut hook_events: Vec<Event> = Vec::new();
        let mut canceled = false;

        for entity_id in entity_ids {
            let entity = self.entities[&entity_id].clone();
            for ability in &entity.abilities {
                if !trigger_matches(&ability.trigger, phase_prefix, action_str, &entity_id, event) {
                    continue;
                }
                if !self.evaluate_conditions(&ability.conditions, &entity_id) {
                    continue;
                }

                // Collect in scan order. Resolution order after the batch push is:
                // FIFO — matches scan order (first scanned resolves first).
                // LIFO — reverse of scan order (last scanned resolves first, sits on top).
                for action in &ability.actions {
                    hook_events.push(Event {
                        source_id: entity_id.clone(),
                        action: resolve_placeholders(action, event),
                    });
                }

                if phase == HookPhase::Before && ability.cancels {
                    canceled = true;
                }
            }
        }

        // Push all collected hook events at once.
        // FIFO: reverse-push to front → first collected sits at the front, resolves first.
        // LIFO: forward-push to back → first collected is deepest, last collected resolves first.
        match order {
            StackOrder::Fifo => {
                for event in hook_events.into_iter().rev() {
                    self.event_queue.push_front(event);
                }
            }
            StackOrder::Lifo => {
                for event in hook_events {
                    self.event_queue.push_back(event);
                }
            }
        }

        canceled
    }

    /// Evaluates all conditions for an ability using AND logic.
    /// `"self"` in `condition.target` resolves to `ability_owner_id`.
    fn evaluate_conditions(&self, conditions: &[Condition], ability_owner_id: &str) -> bool {
        for cond in conditions {
            let target_id = if cond.target == "self" {
                ability_owner_id
            } else {
                cond.target.as_str()
            };

            let Some(entity) = self.entities.get(target_id) else {
                return false;
            };

            let Some(&prop_val) = entity.properties.get(&cond.property) else {
                return false;
            };

            let passes = match cond.operator.as_str() {
                "==" => prop_val == cond.value,
                "!=" => prop_val != cond.value,
                ">" => prop_val > cond.value,
                ">=" => prop_val >= cond.value,
                "<" => prop_val < cond.value,
                "<=" => prop_val <= cond.value,
                _ => false,
            };

            if !passes {
                return false;
            }
        }
        true
    }

    // ==========================================
    // ACTION EXECUTION
    // ==========================================

    /// Applies a single action to the game state and records animations where applicable.
    fn execute_action(&mut self, event: &Event) {
        match &event.action {
            Action::MutateProperty {
                target_id,
                property,
                delta,
            } => {
                if let Some(entity) = self.entities.get_mut(target_id) {
                    let val = entity.properties.entry(property.clone()).or_insert(0);
                    *val += delta;

                    let text = if *delta >= 0 {
                        format!("+{}", delta)
                    } else {
                        delta.to_string()
                    };
                    let color = if *delta < 0 { "red" } else { "green" };

                    self.pending_animations.push(Animation::FloatText {
                        target_id: target_id.clone(),
                        text,
                        color: color.to_string(),
                    });
                }
            }

            Action::MoveEntity {
                entity_id,
                from_zone,
                to_zone,
                index,
            } => {
                // Guard: both zones must exist before mutating anything.
                // If to_zone is missing and we removed the entity from from_zone first,
                // the entity would be lost from all zones with no way to recover.
                // Guard: both zones must exist before mutating anything.
                // If to_zone is missing and we removed the entity from from_zone first,
                // the entity would be lost from all zones with no way to recover.
                if !self.zones.contains_key(from_zone) || !self.zones.contains_key(to_zone) {
                    return;
                }
                // Only insert into to_zone if the entity was actually present in from_zone.
                // This prevents phantoms (entity not in from_zone) and duplicates
                // (entity already in to_zone) from corrupting zone membership.
                let removed = if let Some(zone) = self.zones.get_mut(from_zone) {
                    let before = zone.entities.len();
                    zone.entities.retain(|id| id != entity_id);
                    zone.entities.len() < before
                } else {
                    false
                };
                if removed {
                    if let Some(zone) = self.zones.get_mut(to_zone) {
                        if !zone.entities.contains(entity_id) {
                            match index {
                                Some(i) => {
                                    let at = (*i).min(zone.entities.len());
                                    zone.entities.insert(at, entity_id.clone());
                                }
                                None => zone.entities.push(entity_id.clone()),
                            }
                        }
                    }
                }
            }

            Action::SpawnEntity { entity, zone_id } => {
                // Guard: zone must exist so the entity isn't orphaned in self.entities
                // without belonging to any zone.
                if !self.zones.contains_key(zone_id) {
                    return;
                }
                let id = entity.id.clone();
                self.entities.insert(id.clone(), entity.clone());
                if let Some(zone) = self.zones.get_mut(zone_id) {
                    zone.entities.push(id);
                }
            }

            Action::EndTurn => {
                // Handled at a higher layer; no direct state mutation here.
            }
        }
    }

    // ==========================================
    // STATE CHECKS
    // ==========================================

    /// Evaluates each configured `StateCheck` against every entity.
    /// For any entity whose watched property satisfies the condition, a `MoveEntity`
    /// event is pushed to the queue — but only if the entity is not already in the
    /// destination zone (prevents re-queuing on every tick).
    fn run_state_checks(&mut self) {
        // Clone to avoid holding a borrow on self while mutating the queue.
        let checks: Vec<StateCheck> = self.state_checks.clone();
        let order = self.stack_order;

        for check in &checks {
            // Skip if the destination zone doesn't exist — execute_action would no-op,
            // leaving entities in place and re-enqueueing the same move every tick.
            if !self.zones.contains_key(&check.move_to_zone) {
                continue;
            }

            let matching_ids: Vec<String> = self
                .entities
                .iter()
                .filter_map(|(id, entity)| {
                    let val = entity.properties.get(&check.watch_property)?;
                    let passes = match check.operator.as_str() {
                        "==" => *val == check.threshold,
                        "!=" => *val != check.threshold,
                        ">" => *val > check.threshold,
                        ">=" => *val >= check.threshold,
                        "<" => *val < check.threshold,
                        "<=" => *val <= check.threshold,
                        _ => false,
                    };
                    passes.then(|| id.clone())
                })
                .collect();

            // Sort for deterministic death-event ordering across runs.
            let mut matching_ids = matching_ids;
            matching_ids.sort();

            // Sort zone IDs for deterministic from_zone selection if an entity is
            // (incorrectly) present in multiple zones simultaneously.
            let mut zone_ids: Vec<String> = self.zones.keys().cloned().collect();
            zone_ids.sort();

            // Collect death events before pushing so we can respect stack_order.
            // FIFO: push to front (resolves immediately, before previously-queued events).
            // LIFO: push to back (top of stack, same priority as hook-triggered events).
            let death_events: Vec<Event> = matching_ids
                .into_iter()
                .filter_map(|entity_id| {
                    let from_zone = zone_ids.iter().find_map(|zone_id| {
                        if zone_id != &check.move_to_zone
                            && self
                                .zones
                                .get(zone_id)
                                .is_some_and(|z| z.entities.contains(&entity_id))
                        {
                            Some(zone_id.clone())
                        } else {
                            None
                        }
                    })?;

                    // An entity must exist in exactly one zone. Multiple zone membership
                    // indicates a bug in the engine's move/spawn logic.
                    debug_assert!(
                        zone_ids
                            .iter()
                            .filter(|zone_id| {
                                *zone_id != &check.move_to_zone
                                    && self
                                        .zones
                                        .get(*zone_id)
                                        .is_some_and(|z| z.entities.contains(&entity_id))
                            })
                            .count()
                            == 1,
                        "entity '{entity_id}' found in multiple zones — invariant violated"
                    );

                    Some(Event {
                        source_id: "engine".to_string(),
                        action: Action::MoveEntity {
                            entity_id,
                            from_zone,
                            to_zone: check.move_to_zone.clone(),
                            index: None,
                        },
                    })
                })
                .collect();

            match order {
                StackOrder::Fifo => {
                    // Reverse so the first dead entity ends up at the front after all pushes.
                    for event in death_events.into_iter().rev() {
                        self.event_queue.push_front(event);
                    }
                }
                StackOrder::Lifo => {
                    for event in death_events {
                        self.event_queue.push_back(event);
                    }
                }
            }
        }
    }
}

// ==========================================
// HELPERS
// ==========================================

/// Returns the canonical action-type string used in trigger names.
fn action_type_str(action: &Action) -> &'static str {
    match action {
        Action::MutateProperty { .. } => "mutate_property",
        Action::MoveEntity { .. } => "move_entity",
        Action::SpawnEntity { .. } => "spawn_entity",
        Action::EndTurn => "end_turn",
    }
}

/// Returns `true` when `trigger` applies to the current phase, action type, and entity.
///
/// Supported trigger formats:
/// - `"on_before_any"` / `"on_after_any"` — every event of that phase.
/// - `"on_after_mutate_property"` — any event of the given action type.
/// - `"on_after_mutate_property:self"` — only when the ability owner is the event's target.
fn trigger_matches(
    trigger: &str,
    phase_prefix: &str,
    action_str: &str,
    entity_id: &str,
    event: &Event,
) -> bool {
    let wildcard = format!("{}any", phase_prefix);
    let exact = format!("{}{}", phase_prefix, action_str);
    let self_trigger = format!("{}{}:self", phase_prefix, action_str);

    if trigger == wildcard || trigger == exact {
        return true;
    }
    if trigger == self_trigger {
        return event_targets_entity(event, entity_id);
    }
    false
}

/// Returns `true` if the event's primary target is `entity_id`.
fn event_targets_entity(event: &Event, entity_id: &str) -> bool {
    match &event.action {
        Action::MutateProperty { target_id, .. } => target_id == entity_id,
        Action::MoveEntity {
            entity_id: moved_id,
            ..
        } => moved_id == entity_id,
        Action::SpawnEntity { entity, .. } => entity.id == entity_id,
        _ => false,
    }
}

/// Resolves placeholder strings in action fields before the action is queued.
///
/// Supported placeholders in `target_id` / `entity_id`:
/// - `"$source"` — the `source_id` of the triggering event.
/// - `"$target"` — the primary target entity of the triggering event.
fn resolve_placeholders(action: &Action, event: &Event) -> Action {
    match action {
        Action::MutateProperty {
            target_id,
            property,
            delta,
        } => Action::MutateProperty {
            target_id: resolve_entity_ref(target_id, event),
            property: property.clone(),
            delta: *delta,
        },
        Action::MoveEntity {
            entity_id,
            from_zone,
            to_zone,
            index,
        } => Action::MoveEntity {
            entity_id: resolve_entity_ref(entity_id, event),
            from_zone: from_zone.clone(),
            to_zone: to_zone.clone(),
            index: *index,
        },
        _ => action.clone(),
    }
}

/// Resolves `"$source"` and `"$target"` placeholders to concrete entity IDs.
fn resolve_entity_ref(id: &str, event: &Event) -> String {
    match id {
        "$source" => event.source_id.clone(),
        "$target" => match &event.action {
            Action::MutateProperty { target_id, .. } => target_id.clone(),
            Action::MoveEntity { entity_id, .. } => entity_id.clone(),
            Action::SpawnEntity { entity, .. } => entity.id.clone(),
            _ => id.to_string(),
        },
        _ => id.to_string(),
    }
}

// ==========================================
// TESTS
// ==========================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::{Ability, Entity, Visibility, Zone};

    fn make_entity(id: &str, props: Vec<(&str, i32)>, abilities: Vec<Ability>) -> Entity {
        Entity {
            id: id.to_string(),
            owner_id: "player_1".to_string(),
            template_id: "template_001".to_string(),
            properties: props.into_iter().map(|(k, v)| (k.to_string(), v)).collect(),
            abilities,
        }
    }

    fn make_zone(id: &str, entity_ids: Vec<&str>) -> Zone {
        Zone {
            id: id.to_string(),
            owner_id: None,
            visibility: Visibility::Public,
            entities: entity_ids.into_iter().map(String::from).collect(),
        }
    }

    // ------------------------------------------
    // Basic MutateProperty
    // ------------------------------------------

    #[test]
    fn mutate_property_updates_entity_and_pushes_animation() {
        let mut state = GameState::new();
        state
            .entities
            .insert("hero".to_string(), make_entity("hero", vec![("health", 20)], vec![]));
        state.event_queue.push_back(Event {
            source_id: "player_1".to_string(),
            action: Action::MutateProperty {
                target_id: "hero".to_string(),
                property: "health".to_string(),
                delta: -5,
            },
        });

        state.resolve_queue();

        assert_eq!(state.entities["hero"].properties["health"], 15);
        assert_eq!(state.pending_animations.len(), 1);
        match &state.pending_animations[0] {
            Animation::FloatText { target_id, text, color } => {
                assert_eq!(target_id, "hero");
                assert_eq!(text, "-5");
                assert_eq!(color, "red");
            }
            _ => panic!("expected FloatText animation"),
        }
    }

    // ------------------------------------------
    // Thorns: after-hook triggers retaliatory event
    // ------------------------------------------

    /// Entity A attacks Entity B. Entity B has the Thorns ability: whenever it is
    /// the target of a MutateProperty, it deals 1 damage back to the source.
    #[test]
    fn thorns_ability_triggers_retaliatory_damage() {
        let thorns = Ability {
            id: "thorns_01".to_string(),
            name: "Thorns".to_string(),
            trigger: "on_after_mutate_property:self".to_string(),
            conditions: vec![],
            actions: vec![Action::MutateProperty {
                target_id: "$source".to_string(),
                property: "health".to_string(),
                delta: -1,
            }],
            cancels: false,
        };

        let mut state = GameState::new();
        state.entities.insert(
            "entity_a".to_string(),
            make_entity("entity_a", vec![("health", 10)], vec![]),
        );
        state.entities.insert(
            "entity_b".to_string(),
            make_entity("entity_b", vec![("health", 10)], vec![thorns]),
        );
        state
            .zones
            .insert("battlefield".to_string(), make_zone("battlefield", vec!["entity_a", "entity_b"]));

        // Entity A deals 3 damage to Entity B.
        state.event_queue.push_back(Event {
            source_id: "entity_a".to_string(),
            action: Action::MutateProperty {
                target_id: "entity_b".to_string(),
                property: "health".to_string(),
                delta: -3,
            },
        });

        state.resolve_queue();

        assert_eq!(
            state.entities["entity_b"].properties["health"],
            7,
            "entity_b should have taken 3 damage"
        );
        assert_eq!(
            state.entities["entity_a"].properties["health"],
            9,
            "entity_a should have taken 1 Thorns damage"
        );
        assert!(state.event_queue.is_empty(), "queue should be fully drained");
    }

    // ------------------------------------------
    // Before-hook cancellation
    // ------------------------------------------

    #[test]
    fn canceling_hook_drops_event_without_mutating_state() {
        let shield = Ability {
            id: "shield_01".to_string(),
            name: "Divine Shield".to_string(),
            trigger: "on_before_mutate_property:self".to_string(),
            conditions: vec![],
            actions: vec![],
            cancels: true,
        };

        let mut state = GameState::new();
        state
            .entities
            .insert("hero".to_string(), make_entity("hero", vec![("health", 10)], vec![shield]));

        state.event_queue.push_back(Event {
            source_id: "enemy".to_string(),
            action: Action::MutateProperty {
                target_id: "hero".to_string(),
                property: "health".to_string(),
                delta: -5,
            },
        });

        state.resolve_queue();

        assert_eq!(
            state.entities["hero"].properties["health"],
            10,
            "health should be unchanged — the attack was canceled"
        );
        assert!(
            state.pending_animations.is_empty(),
            "no animation should be emitted for a canceled event"
        );
    }

    // ------------------------------------------
    // Condition-gated hook
    // ------------------------------------------

    #[test]
    fn conditional_hook_only_fires_when_condition_passes() {
        // Ability fires only when the owner's health is above 5.
        let counterattack = Ability {
            id: "counter_01".to_string(),
            name: "Counterattack".to_string(),
            trigger: "on_after_mutate_property:self".to_string(),
            conditions: vec![Condition {
                target: "self".to_string(),
                property: "health".to_string(),
                operator: ">".to_string(),
                value: 5,
            }],
            actions: vec![Action::MutateProperty {
                target_id: "$source".to_string(),
                property: "health".to_string(),
                delta: -2,
            }],
            cancels: false,
        };

        let mut state = GameState::new();
        state.entities.insert(
            "entity_a".to_string(),
            make_entity("entity_a", vec![("health", 10)], vec![]),
        );
        // Entity B starts at health 4 — condition (health > 5) will NOT pass.
        state.entities.insert(
            "entity_b".to_string(),
            make_entity("entity_b", vec![("health", 4)], vec![counterattack]),
        );
        state
            .zones
            .insert("battlefield".to_string(), make_zone("battlefield", vec!["entity_a", "entity_b"]));

        state.event_queue.push_back(Event {
            source_id: "entity_a".to_string(),
            action: Action::MutateProperty {
                target_id: "entity_b".to_string(),
                property: "health".to_string(),
                delta: -1,
            },
        });

        state.resolve_queue();

        // Entity B's hook did not fire, so Entity A is untouched.
        assert_eq!(state.entities["entity_b"].properties["health"], 3);
        assert_eq!(
            state.entities["entity_a"].properties["health"],
            10,
            "entity_a should be unharmed — condition blocked the hook"
        );
    }

    // ------------------------------------------
    // LIFO (MTG-style stack) resolution order
    // ------------------------------------------

    /// In LIFO mode the last event pushed resolves first — identical to the MTG stack.
    /// We verify this via animation order: two events pushed A then B should produce
    /// animations in B-then-A order.
    #[test]
    fn lifo_resolves_events_in_reverse_push_order() {
        let mut state = GameState::new();
        state.stack_order = StackOrder::Lifo;
        state
            .entities
            .insert("hero".to_string(), make_entity("hero", vec![("health", 20)], vec![]));

        // Push event A first, then event B.
        state.event_queue.push_back(Event {
            source_id: "player".to_string(),
            action: Action::MutateProperty {
                target_id: "hero".to_string(),
                property: "health".to_string(),
                delta: -3, // event A
            },
        });
        state.event_queue.push_back(Event {
            source_id: "player".to_string(),
            action: Action::MutateProperty {
                target_id: "hero".to_string(),
                property: "health".to_string(),
                delta: -2, // event B
            },
        });

        state.resolve_queue();

        // Final health is the same regardless of order (20 - 3 - 2 = 15).
        assert_eq!(state.entities["hero"].properties["health"], 15);

        // The animation log reveals resolution order: B (-2) resolved before A (-3).
        assert_eq!(state.pending_animations.len(), 2);
        match (&state.pending_animations[0], &state.pending_animations[1]) {
            (
                Animation::FloatText { text: first, .. },
                Animation::FloatText { text: second, .. },
            ) => {
                assert_eq!(first, "-2", "LIFO: event B (last pushed) resolves first");
                assert_eq!(second, "-3", "LIFO: event A (first pushed) resolves second");
            }
            _ => panic!("expected two FloatText animations"),
        }
    }

    // ------------------------------------------
    // Death state check → auto-move to graveyard
    // ------------------------------------------

    fn make_death_check(move_to_zone: &str) -> StateCheck {
        StateCheck {
            watch_property: "health".to_string(),
            operator: "<=".to_string(),
            threshold: 0,
            move_to_zone: move_to_zone.to_string(),
        }
    }

    #[test]
    fn entity_with_zero_health_is_moved_to_graveyard() {
        let mut state = GameState::new();
        state.state_checks.push(make_death_check("graveyard"));
        state.entities.insert(
            "creature".to_string(),
            make_entity("creature", vec![("health", 1)], vec![]),
        );
        state
            .zones
            .insert("battlefield".to_string(), make_zone("battlefield", vec!["creature"]));
        state
            .zones
            .insert("graveyard".to_string(), make_zone("graveyard", vec![]));

        state.event_queue.push_back(Event {
            source_id: "player_1".to_string(),
            action: Action::MutateProperty {
                target_id: "creature".to_string(),
                property: "health".to_string(),
                delta: -1,
            },
        });

        state.resolve_queue();

        assert_eq!(state.entities["creature"].properties["health"], 0);
        assert!(
            !state.zones["battlefield"].entities.contains(&"creature".to_string()),
            "creature should be removed from battlefield"
        );
        assert!(
            state.zones["graveyard"].entities.contains(&"creature".to_string()),
            "creature should be in graveyard"
        );
    }

    #[test]
    fn state_check_uses_configured_zone_name() {
        // A Pokémon-style game where dead entities go to "discard_pile", not "graveyard".
        let mut state = GameState::new();
        state.state_checks.push(StateCheck {
            watch_property: "hp".to_string(),
            operator: "<=".to_string(),
            threshold: 0,
            move_to_zone: "discard_pile".to_string(),
        });
        state.entities.insert(
            "pikachu".to_string(),
            make_entity("pikachu", vec![("hp", 1)], vec![]),
        );
        state
            .zones
            .insert("active".to_string(), make_zone("active", vec!["pikachu"]));
        state
            .zones
            .insert("discard_pile".to_string(), make_zone("discard_pile", vec![]));

        state.event_queue.push_back(Event {
            source_id: "opponent".to_string(),
            action: Action::MutateProperty {
                target_id: "pikachu".to_string(),
                property: "hp".to_string(),
                delta: -1,
            },
        });

        state.resolve_queue();

        assert!(
            state.zones["discard_pile"].entities.contains(&"pikachu".to_string()),
            "pikachu should be in the discard_pile, not a hardcoded graveyard"
        );
        assert!(
            !state.zones["active"].entities.contains(&"pikachu".to_string()),
        );
    }

    // ------------------------------------------
    // SpawnEntity action execution
    // ------------------------------------------

    #[test]
    fn spawn_entity_adds_entity_to_state_and_zone() {
        let mut state = GameState::new();
        state
            .zones
            .insert("battlefield".to_string(), make_zone("battlefield", vec![]));

        let token = make_entity("token_001", vec![("power", 1), ("toughness", 1)], vec![]);
        state.event_queue.push_back(Event {
            source_id: "player_1".to_string(),
            action: Action::SpawnEntity {
                entity: token,
                zone_id: "battlefield".to_string(),
            },
        });

        state.resolve_queue();

        assert!(
            state.entities.contains_key("token_001"),
            "spawned entity should exist in state"
        );
        assert_eq!(state.entities["token_001"].properties["power"], 1);
        assert!(
            state.zones["battlefield"].entities.contains(&"token_001".to_string()),
            "spawned entity should be placed in the target zone"
        );
    }

    // ------------------------------------------
    // $target placeholder
    // ------------------------------------------

    /// `$target` in an ability's action resolves to the primary target of the
    /// triggering event — not the ability's owner and not the source.
    ///
    /// Scenario: Entity B has a "Redirect" ability that triggers on any MutateProperty
    /// and moves the targeted entity out of the battlefield. The ability uses `$target`
    /// to identify which entity to move, proving the placeholder resolves correctly.
    /// A MoveEntity action is used as the effect so that it doesn't re-trigger the
    /// `on_after_mutate_property` hook, keeping the test free of cascades.
    #[test]
    fn dollar_target_resolves_to_triggering_event_target() {
        let redirect = Ability {
            id: "redirect_01".to_string(),
            name: "Redirect".to_string(),
            trigger: "on_after_mutate_property".to_string(),
            conditions: vec![],
            actions: vec![Action::MoveEntity {
                entity_id: "$target".to_string(),
                from_zone: "battlefield".to_string(),
                to_zone: "hand".to_string(),
                index: None,
            }],
            cancels: false,
        };

        let mut state = GameState::new();
        state.entities.insert(
            "entity_a".to_string(),
            make_entity("entity_a", vec![("health", 10)], vec![]),
        );
        state.entities.insert(
            "entity_b".to_string(),
            make_entity("entity_b", vec![("health", 10)], vec![redirect]),
        );
        state.zones.insert(
            "battlefield".to_string(),
            make_zone("battlefield", vec!["entity_a", "entity_b"]),
        );
        state
            .zones
            .insert("hand".to_string(), make_zone("hand", vec![]));

        // Mutate entity_a. Entity B's hook fires; $target should resolve to entity_a.
        state.event_queue.push_back(Event {
            source_id: "player".to_string(),
            action: Action::MutateProperty {
                target_id: "entity_a".to_string(),
                property: "health".to_string(),
                delta: -3,
            },
        });

        state.resolve_queue();

        assert!(
            state.zones["hand"].entities.contains(&"entity_a".to_string()),
            "$target should have resolved to entity_a, moving it to hand"
        );
        assert!(
            !state.zones["battlefield"].entities.contains(&"entity_a".to_string()),
        );
        // entity_b is unaffected.
        assert!(state.zones["battlefield"].entities.contains(&"entity_b".to_string()));
    }

    // ------------------------------------------
    // Wildcard trigger (on_after_any)
    // ------------------------------------------

    /// Helper: builds an "event counter" ability that fires on `on_after_any` and
    /// increments `counter` on the owner entity.
    ///
    /// The condition `counter < cap` is required to prevent the ability from
    /// triggering itself indefinitely — every MutateProperty it pushes (to increment
    /// the counter) would itself match `on_after_any` and fire the ability again.
    /// The cap makes the self-triggering terminate after a known number of iterations.
    fn make_counter_ability(cap: i32) -> Ability {
        Ability {
            id: "counter_ability".to_string(),
            name: "Event Counter".to_string(),
            trigger: "on_after_any".to_string(),
            conditions: vec![Condition {
                target: "self".to_string(),
                property: "counter".to_string(),
                operator: "<".to_string(),
                value: cap,
            }],
            actions: vec![Action::MutateProperty {
                target_id: "$source".to_string(), // resolves to the triggering event's source_id; tests set this to "watcher"
                property: "counter".to_string(),
                delta: 1,
            }],
            cancels: false,
        }
    }

    #[test]
    fn wildcard_trigger_fires_for_mutate_property() {
        let mut state = GameState::new();
        // cap=1: the counter increments once for the original event, then the
        // self-triggered counter+1 event finds counter=1 which is not < 1, so stops.
        let mut watcher = make_entity("watcher", vec![("counter", 0)], vec![]);
        watcher.abilities.push(make_counter_ability(1));
        state.entities.insert("watcher".to_string(), watcher);
        state
            .entities
            .insert("target".to_string(), make_entity("target", vec![("health", 10)], vec![]));

        state.event_queue.push_back(Event {
            source_id: "watcher".to_string(),
            action: Action::MutateProperty {
                target_id: "target".to_string(),
                property: "health".to_string(),
                delta: -1,
            },
        });

        state.resolve_queue();

        assert_eq!(
            state.entities["watcher"].properties["counter"],
            1,
            "on_after_any should fire for a MutateProperty action"
        );
    }

    #[test]
    fn wildcard_trigger_fires_for_move_entity() {
        let mut state = GameState::new();
        let mut watcher = make_entity("watcher", vec![("counter", 0)], vec![]);
        watcher.abilities.push(make_counter_ability(1));
        state.entities.insert("watcher".to_string(), watcher);
        state
            .entities
            .insert("token".to_string(), make_entity("token", vec![], vec![]));
        state.zones.insert(
            "battlefield".to_string(),
            make_zone("battlefield", vec!["token"]),
        );
        state
            .zones
            .insert("graveyard".to_string(), make_zone("graveyard", vec![]));

        state.event_queue.push_back(Event {
            source_id: "watcher".to_string(),
            action: Action::MoveEntity {
                entity_id: "token".to_string(),
                from_zone: "battlefield".to_string(),
                to_zone: "graveyard".to_string(),
                index: None,
            },
        });

        state.resolve_queue();

        assert_eq!(
            state.entities["watcher"].properties["counter"],
            1,
            "on_after_any should fire for a MoveEntity action"
        );
    }

    #[test]
    fn resolve_queue_bounded_returns_err_when_limit_exceeded() {
        let mut state = GameState::default();

        // Push more events than the limit allows.
        for _ in 0..5 {
            state.event_queue.push_back(Event {
                source_id: "player_1".to_string(),
                action: Action::EndTurn,
            });
        }

        let result = state.resolve_queue_bounded(3);
        assert!(result.is_err(), "expected Err when step limit is exceeded");
        let msg = result.unwrap_err();
        assert!(msg.contains("resolution limit exceeded"), "unexpected message: {msg}");
        // Remaining events must still be in the queue — none were silently dropped.
        assert!(!state.event_queue.is_empty(), "unprocessed events must remain in the queue");
    }

    #[test]
    fn resolve_queue_bounded_ok_when_within_limit() {
        let mut state = GameState::default();

        for _ in 0..3 {
            state.event_queue.push_back(Event {
                source_id: "player_1".to_string(),
                action: Action::EndTurn,
            });
        }

        assert!(state.resolve_queue_bounded(10).is_ok());
        assert!(state.event_queue.is_empty());
    }
}
