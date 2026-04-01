/**
 * REST API response types.
 *
 * These mirror the JSON shapes returned by the Phoenix controllers.
 * Engine/runtime types live in ditto.generated.ts — keep them separate.
 */

export type ZoneConfig = {
	name: string;
	visibility: 'Public' | 'OwnerOnly' | 'Hidden';
	capacity: number | null;
};

export type PropertyConfig = {
	name: string;
	default: number;
};

/**
 * ECA (Event-Condition-Action) types matching ditto_core::state.rs exactly.
 * These will move to ditto.generated.ts once CAR-58 auto-generation is wired.
 */

export type ConditionOperator = '==' | '!=' | '<' | '<=' | '>' | '>=';

export type EcaCondition = {
	target: string;
	property: string;
	operator: ConditionOperator;
	value: number;
};

export type EcaAction =
	| { MutateProperty: { target_id: string; property: string; delta: number } }
	| { MoveEntity: { entity_id: string; from_zone: string; to_zone: string; index: number | null } }
	| { SpawnEntity: { entity: Record<string, unknown>; zone_id: string } }
	| 'EndTurn';

export type EcaRule = {
	id: string;
	name: string;
	trigger: string;
	conditions: EcaCondition[];
	actions: EcaAction[];
	cancels: boolean;
};

export type GameConfig = {
	zones: ZoneConfig[];
	properties: PropertyConfig[];
	rules: EcaRule[];
	win_conditions: EcaRule[];
};

/** Shape returned by GET /api/games, GET /api/games/:id, POST /api/games, PATCH /api/games/:id */
export type Game = {
	id: number;
	title: string;
	description: string | null;
	config: Partial<GameConfig> & Record<string, unknown>;
	card_count: number;
	deck_count: number;
	inserted_at: string;
	updated_at: string;
};
