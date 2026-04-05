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

/** Shape returned by /api/games/:id/cards endpoints */
export type Card = {
	id: number;
	game_id: number;
	name: string;
	card_type: string;
	background_color: string | null;
	properties: Record<string, number>;
	abilities: EcaRule[];
	inserted_at: string;
	updated_at: string;
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

/** Partial card shape nested inside deck entries (backend omits game_id, inserted_at, updated_at) */
export type DeckEntryCard = Pick<Card, 'id' | 'name' | 'card_type' | 'background_color' | 'properties' | 'abilities'>;

/** Deck list item — returned by GET /api/games/:id/decks (no entries) */
export type DeckSummary = {
	id: number;
	game_id: number;
	name: string;
	inserted_at: string;
	updated_at: string;
};

/** Entry in a deck — card with quantity */
export type DeckEntry = {
	card_id: number;
	quantity: number;
	card: DeckEntryCard;
};

/** Full deck with entries — returned by GET/PATCH /api/games/:id/decks/:id */
export type Deck = DeckSummary & {
	entries: DeckEntry[];
};
