/**
 * REST API response types.
 *
 * These mirror the JSON shapes returned by the Phoenix controllers.
 * Engine/runtime types live in ditto.generated.ts — keep them separate.
 */

export type ZoneConfig = {
	name: string;
	visibility: 'public' | 'private' | 'hidden';
	capacity: number | null;
};

export type PropertyConfig = {
	name: string;
	default: number;
};

export type EcaRule = Record<string, unknown>;

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
	config: Record<string, unknown>;
	card_count: number;
	deck_count: number;
	inserted_at: string;
	updated_at: string;
};
