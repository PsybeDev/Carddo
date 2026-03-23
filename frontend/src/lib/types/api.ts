/**
 * REST API response types.
 *
 * These mirror the JSON shapes returned by the Phoenix controllers.
 * Engine/runtime types live in ditto.generated.ts — keep them separate.
 */

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
