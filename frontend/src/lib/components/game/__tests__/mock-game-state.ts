import type { GameState, Entity, Zone } from '$lib/types/ditto.generated';

// Player identifiers
export const PLAYER_1_ID = 'player-1-uuid';
export const PLAYER_2_ID = 'player-2-uuid';

// Mock entities with varied properties and template IDs
export const mockEntities: Record<string, Entity> = {
	entity_a: {
		id: 'entity_a',
		owner_id: PLAYER_1_ID,
		template_id: 'card_template_a',
		properties: { str: 5, def: 3 },
		abilities: []
	},
	entity_b: {
		id: 'entity_b',
		owner_id: PLAYER_1_ID,
		template_id: 'card_template_b',
		properties: { spd: 7, mana: 2 },
		abilities: []
	},
	entity_c: {
		id: 'entity_c',
		owner_id: PLAYER_1_ID,
		template_id: 'card_template_c',
		properties: { health: 10, cost: 4 },
		abilities: []
	},
	entity_d: {
		id: 'entity_d',
		owner_id: PLAYER_1_ID,
		template_id: 'card_template_d',
		properties: { power: 6 },
		abilities: []
	},
	entity_e: {
		id: 'entity_e',
		owner_id: PLAYER_2_ID,
		template_id: 'card_template_e',
		properties: { str: 4, def: 6 },
		abilities: []
	},
	entity_tapped: {
		id: 'entity_tapped',
		owner_id: PLAYER_1_ID,
		template_id: 'card_template_tapped',
		properties: { str: 3, tapped: 1 },
		abilities: []
	}
};

// Mock zones with different visibility and ownership patterns
export const mockZones: Record<string, Zone> = {
	zone_a_p1: {
		id: 'zone_a_p1',
		owner_id: PLAYER_1_ID,
		visibility: 'Public',
		entities: ['entity_a', 'entity_b', 'entity_tapped']
	},
	zone_b_p1: {
		id: 'zone_b_p1',
		owner_id: PLAYER_1_ID,
		visibility: 'OwnerOnly',
		entities: ['entity_c', 'entity_d']
	},
	zone_c_p2: {
		id: 'zone_c_p2',
		owner_id: PLAYER_2_ID,
		visibility: 'OwnerOnly',
		entities: ['entity_e']
	},
	zone_d_hidden: {
		id: 'zone_d_hidden',
		owner_id: PLAYER_1_ID,
		visibility: { Hidden: 3 },
		entities: []
	},
	zone_e_empty_hidden: {
		id: 'zone_e_empty_hidden',
		owner_id: PLAYER_1_ID,
		visibility: { Hidden: 0 },
		entities: []
	},
	zone_f_neutral: {
		id: 'zone_f_neutral',
		owner_id: null,
		visibility: 'Public',
		entities: []
	},
	zone_g_empty: {
		id: 'zone_g_empty',
		owner_id: PLAYER_2_ID,
		visibility: 'Public',
		entities: []
	}
};

// Complete mock GameState
export const mockGameState: GameState = {
	entities: mockEntities,
	zones: mockZones,
	event_queue: [],
	pending_animations: [],
	stack_order: 'Fifo',
	state_checks: []
};

/**
 * Create a GameState with optional overrides for testing different scenarios.
 * @param overrides Partial GameState overrides to customize the fixture
 * @returns A complete GameState with defaults merged with overrides
 */
export function createMockGameState(overrides?: Partial<GameState>): GameState {
	return {
		...mockGameState,
		...overrides,
		// Deep merge entities and zones to handle overrides properly
		entities: {
			...mockGameState.entities,
			...(overrides?.entities ?? {})
		},
		zones: {
			...mockGameState.zones,
			...(overrides?.zones ?? {})
		}
	};
}
