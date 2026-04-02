/**
 * Canonical ECA rule JSON schema — mirrors ditto_core::state::Ability.
 *
 * This is the ground truth for what the engine accepts.
 * All rule builder validation must use this shape.
 */

export const TRIGGER_PHASES = ['on_before_', 'on_after_'] as const;
export const TRIGGER_ACTION_TYPES = [
	'mutate_property',
	'move_entity',
	'spawn_entity',
	'end_turn',
	'any'
] as const;
export const CONDITION_OPERATORS = ['==', '!=', '<', '<=', '>', '>='] as const;

/** Trigger format: `"on_before_<action_type>"` or `"on_after_<action_type>"`, with optional `:self` suffix. */
export type TriggerPhase = (typeof TRIGGER_PHASES)[number];
export type TriggerActionType = (typeof TRIGGER_ACTION_TYPES)[number];
export type ConditionOperator = (typeof CONDITION_OPERATORS)[number];

/**
 * Condition shape matching ditto_core::state::Condition.
 * - target: entity reference ("self", "$source", "$target", or a concrete ID)
 * - property: a property name defined in game config
 * - operator: one of the condition operators
 * - value: i32 comparison value
 */
export type SchemaCondition = {
	target: string;
	property: string;
	operator: ConditionOperator;
	value: number;
};

/**
 * Action variants matching ditto_core::state::Action.
 * SpawnEntity.entity is deferred — uses Record<string, unknown> until CAR-58.
 */
export type SchemaAction =
	| { MutateProperty: { target_id: string; property: string; delta: number } }
	| { MoveEntity: { entity_id: string; from_zone: string; to_zone: string; index?: number | null } }
	| { SpawnEntity: { entity: Record<string, unknown>; zone_id: string } }
	| 'EndTurn';

/**
 * Full ECA rule shape matching ditto_core::state::Ability.
 */
export type SchemaRule = {
	id: string;
	name: string;
	/** Trigger string: e.g. "on_after_mutate_property:self" */
	trigger: string;
	conditions: SchemaCondition[];
	actions: SchemaAction[];
	/** Only meaningful for before-phase triggers */
	cancels: boolean;
};

/**
 * Valid trigger string format:
 * - `{phase}{action_type}` or `{phase}{action_type}:self`
 * - phase: "on_before_" | "on_after_"
 * - action_type: "mutate_property" | "move_entity" | "spawn_entity" | "end_turn" | "any"
 * - suffix ":self" restricts to events targeting the ability owner
 */
export function isValidTrigger(trigger: string): boolean {
	return /^on_(?:before|after)_(?:mutate_property|move_entity|spawn_entity|end_turn|any)(?::self)?$/.test(
		trigger
	);
}

/** Validates a single trigger action type string. */
export function isValidActionType(actionType: string): actionType is TriggerActionType {
	return (TRIGGER_ACTION_TYPES as readonly string[]).includes(actionType);
}
