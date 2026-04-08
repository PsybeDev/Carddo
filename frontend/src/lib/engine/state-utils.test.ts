import { describe, it, expect } from 'vitest';

import { findEntityZone, stripPrivateState } from '$lib/engine/state-utils';
import type { GameState } from '$lib/types/ditto.generated';

// Minimal fixture helpers
function makeEntity(id: string, ownerId = 'p1') {
	return {
		id,
		owner_id: ownerId,
		template_id: 'card',
		properties: { health: 10 },
		abilities: []
	};
}

function makeBaseState(): GameState {
	return {
		entities: {},
		zones: {},
		event_queue: [],
		pending_animations: [],
		stack_order: 'Fifo',
		state_checks: []
	};
}

// ─── findEntityZone ──────────────────────────────────────────────────────────

describe('findEntityZone', () => {
	it('returns zone id when entity is in "hand"', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: { id: 'hand', owner_id: 'p1', visibility: 'OwnerOnly', entities: ['e1'] },
				battlefield: { id: 'battlefield', owner_id: null, visibility: 'Public', entities: [] }
			}
		};

		expect(findEntityZone(state, 'e1')).toBe('hand');
	});

	it('returns zone id when entity is in "battlefield"', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e2: makeEntity('e2') },
			zones: {
				hand: { id: 'hand', owner_id: 'p1', visibility: 'OwnerOnly', entities: [] },
				battlefield: { id: 'battlefield', owner_id: null, visibility: 'Public', entities: ['e2'] }
			}
		};

		expect(findEntityZone(state, 'e2')).toBe('battlefield');
	});

	it('returns null when entity is not in any zone', () => {
		const state: GameState = {
			...makeBaseState(),
			zones: {
				hand: { id: 'hand', owner_id: 'p1', visibility: 'OwnerOnly', entities: ['e1'] }
			}
		};

		expect(findEntityZone(state, 'unknown-entity')).toBeNull();
	});

	it('returns null when zones object is empty', () => {
		const state: GameState = makeBaseState();

		expect(findEntityZone(state, 'e1')).toBeNull();
	});
});

// ─── stripPrivateState ───────────────────────────────────────────────────────

describe('stripPrivateState', () => {
	it('Public zone retains all entities in the returned state', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1'), e2: makeEntity('e2') },
			zones: {
				battlefield: {
					id: 'battlefield',
					owner_id: null,
					visibility: 'Public',
					entities: ['e1', 'e2']
				}
			}
		};

		const result = stripPrivateState(state, 'p1');

		expect(result.zones['battlefield'].entities).toEqual(['e1', 'e2']);
		expect(result.entities['e1']).toBeDefined();
		expect(result.entities['e2']).toBeDefined();
	});

	it('Hidden zone has entities array emptied and entity records removed', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1'), e2: makeEntity('e2') },
			zones: {
				deck: {
					id: 'deck',
					owner_id: 'p2',
					visibility: { Hidden: 30 },
					entities: ['e1', 'e2']
				}
			}
		};

		const result = stripPrivateState(state, 'p1');

		expect(result.zones['deck'].entities).toEqual([]);
		expect(result.entities['e1']).toBeUndefined();
		expect(result.entities['e2']).toBeUndefined();
	});

	it('OwnerOnly zone owned by currentPlayerId retains all entities', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1', 'p1') },
			zones: {
				hand: {
					id: 'hand',
					owner_id: 'p1',
					visibility: 'OwnerOnly',
					entities: ['e1']
				}
			}
		};

		const result = stripPrivateState(state, 'p1');

		expect(result.zones['hand'].entities).toEqual(['e1']);
		expect(result.entities['e1']).toBeDefined();
	});

	it('OwnerOnly zone owned by another player has entities emptied and records removed', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1', 'p2') },
			zones: {
				opponent_hand: {
					id: 'opponent_hand',
					owner_id: 'p2',
					visibility: 'OwnerOnly',
					entities: ['e1']
				}
			}
		};

		const result = stripPrivateState(state, 'p1');

		expect(result.zones['opponent_hand'].entities).toEqual([]);
		expect(result.entities['e1']).toBeUndefined();
	});

	it('mixed state returns correct filtered result across all zone types', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: {
				pub1: makeEntity('pub1'),
				pub2: makeEntity('pub2'),
				hidden1: makeEntity('hidden1', 'p2'),
				mine1: makeEntity('mine1', 'p1'),
				opp1: makeEntity('opp1', 'p2')
			},
			zones: {
				battlefield: {
					id: 'battlefield',
					owner_id: null,
					visibility: 'Public',
					entities: ['pub1', 'pub2']
				},
				p2_deck: {
					id: 'p2_deck',
					owner_id: 'p2',
					visibility: { Hidden: 20 },
					entities: ['hidden1']
				},
				p1_hand: {
					id: 'p1_hand',
					owner_id: 'p1',
					visibility: 'OwnerOnly',
					entities: ['mine1']
				},
				p2_hand: {
					id: 'p2_hand',
					owner_id: 'p2',
					visibility: 'OwnerOnly',
					entities: ['opp1']
				}
			}
		};

		const result = stripPrivateState(state, 'p1');

		// Public — untouched
		expect(result.zones['battlefield'].entities).toEqual(['pub1', 'pub2']);
		expect(result.entities['pub1']).toBeDefined();
		expect(result.entities['pub2']).toBeDefined();

		// Hidden — stripped
		expect(result.zones['p2_deck'].entities).toEqual([]);
		expect(result.entities['hidden1']).toBeUndefined();

		// OwnerOnly mine — retained
		expect(result.zones['p1_hand'].entities).toEqual(['mine1']);
		expect(result.entities['mine1']).toBeDefined();

		// OwnerOnly opponent — stripped
		expect(result.zones['p2_hand'].entities).toEqual([]);
		expect(result.entities['opp1']).toBeUndefined();
	});

	it('does NOT mutate the original gameState', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1', 'p2') },
			zones: {
				opponent_hand: {
					id: 'opponent_hand',
					owner_id: 'p2',
					visibility: 'OwnerOnly',
					entities: ['e1']
				}
			}
		};

		// Deep snapshot before
		const before = JSON.parse(JSON.stringify(state));

		stripPrivateState(state, 'p1');

		// Original must be identical
		expect(state).toEqual(before);
		expect(state.zones['opponent_hand'].entities).toEqual(['e1']);
		expect(state.entities['e1']).toBeDefined();
	});
});
