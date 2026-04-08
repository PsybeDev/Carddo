import { describe, it, expect, beforeEach } from 'vitest';

import { applyActionOptimistically, gameStore } from '$lib/stores/game.svelte';
import type { Action, Entity, GameState, Zone } from '$lib/types/ditto.generated';

function makeEntity(id: string, ownerId = 'p1'): Entity {
	return {
		id,
		owner_id: ownerId,
		template_id: 'card',
		properties: { health: 10 },
		abilities: []
	};
}

function makeZone(id: string, entities: string[], ownerId: string | null = null): Zone {
	return {
		id,
		owner_id: ownerId,
		visibility: 'Public',
		entities
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

describe('applyActionOptimistically', () => {
	it('moves entity from source zone to target zone', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [], null)
			}
		};

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		const result = applyActionOptimistically(state, action);

		expect(result.zones['hand'].entities).toEqual([]);
		expect(result.zones['battlefield'].entities).toEqual(['e1']);
	});

	it('preserves entity in entities map (does not delete the Entity object)', () => {
		const entity = makeEntity('e1');
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: entity },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				graveyard: makeZone('graveyard', [], null)
			}
		};

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'graveyard', index: null }
		};

		const result = applyActionOptimistically(state, action);

		expect(result.entities['e1']).toEqual(entity);
		expect(result.entities['e1']).toBeDefined();
	});

	it('returns unchanged state for MutateProperty action', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		const action: Action = {
			MutateProperty: { target_id: 'e1', property: 'health', delta: -3 }
		};

		const result = applyActionOptimistically(state, action);

		expect(result).toEqual(state);
		expect(result).not.toBe(state);
	});

	it('returns unchanged state for SpawnEntity action', () => {
		const state = makeBaseState();
		const action: Action = {
			SpawnEntity: { entity: makeEntity('new-card'), zone_id: 'hand' }
		};

		const result = applyActionOptimistically(state, action);

		expect(result).toEqual(state);
		expect(result).not.toBe(state);
	});

	it('returns unchanged state for EndTurn action', () => {
		const state = makeBaseState();

		const result = applyActionOptimistically(state, 'EndTurn');

		expect(result).toEqual(state);
		expect(result).not.toBe(state);
	});

	it('returns unchanged state when from_zone does not exist', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { battlefield: makeZone('battlefield', []) }
		};

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		const result = applyActionOptimistically(state, action);

		expect(result).toEqual(state);
		expect(result).not.toBe(state);
	});

	it('returns unchanged state when to_zone does not exist', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		const result = applyActionOptimistically(state, action);

		expect(result).toEqual(state);
		expect(result).not.toBe(state);
	});

	it('returns unchanged state when entity not in from_zone', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', [], 'p1'),
				battlefield: makeZone('battlefield', [])
			}
		};

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		const result = applyActionOptimistically(state, action);

		expect(result).toEqual(state);
		expect(result).not.toBe(state);
	});

	it('does not mutate the original state (immutability check)', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [])
			}
		};

		const before = JSON.parse(JSON.stringify(state));

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		const result = applyActionOptimistically(state, action);

		expect(state).toEqual(before);
		expect(result).not.toBe(state);
	});

	it('inserts at index position when index is provided', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: {
				e1: makeEntity('e1'),
				e2: makeEntity('e2'),
				e3: makeEntity('e3')
			},
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', ['e2', 'e3'])
			}
		};

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: 1 }
		};

		const result = applyActionOptimistically(state, action);

		expect(result.zones['battlefield'].entities).toEqual(['e2', 'e1', 'e3']);
	});
});

describe('initGame', () => {
	beforeEach(() => {
		gameStore.reset();
	});

	it('sets serverState and optimisticState from provided state', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		gameStore.initGame(state, 'p1');

		expect(gameStore.serverState).toEqual(state);
		expect(gameStore.serverState).not.toBe(state);
		expect(gameStore.optimisticState).toEqual(state);
		expect(gameStore.optimisticState).not.toBe(state);
	});

	it('sets currentPlayerId', () => {
		const state = makeBaseState();
		gameStore.initGame(state, 'player-123');

		expect(gameStore.currentPlayerId).toBe('player-123');
	});

	it('clears pendingAction and gameOver', () => {
		const state = makeBaseState();
		gameStore.initGame(state, 'p1');

		expect(gameStore.pendingAction).toBeNull();
		expect(gameStore.gameOver).toBeNull();
	});

	it('called twice overwrites cleanly', () => {
		const stateA: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		const stateB: GameState = {
			...makeBaseState(),
			entities: { e2: makeEntity('e2') },
			zones: { battlefield: makeZone('battlefield', ['e2'], null) }
		};

		gameStore.initGame(stateA, 'p1');
		gameStore.initGame(stateB, 'p2');

		expect(gameStore.serverState).toEqual(stateB);
		expect(gameStore.optimisticState).toEqual(stateB);
		expect(gameStore.currentPlayerId).toBe('p2');
	});
});

describe('gameStore getters', () => {
	beforeEach(() => {
		gameStore.reset();
	});

	it('return null before init', () => {
		expect(gameStore.serverState).toBeNull();
		expect(gameStore.optimisticState).toBeNull();
		expect(gameStore.pendingAction).toBeNull();
		expect(gameStore.gameOver).toBeNull();
		expect(gameStore.currentPlayerId).toBe('');
	});
});

describe('reset', () => {
	beforeEach(() => {
		gameStore.reset();
	});

	it('clears all state', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		gameStore.initGame(state, 'p1');
		gameStore.reset();

		expect(gameStore.serverState).toBeNull();
		expect(gameStore.optimisticState).toBeNull();
		expect(gameStore.pendingAction).toBeNull();
		expect(gameStore.gameOver).toBeNull();
		expect(gameStore.currentPlayerId).toBe('');
	});
});

describe('attemptMove', () => {
	it.todo('applies optimistic MoveEntity to optimisticState');
	it.todo('does not modify serverState');
	it.todo('sets pendingAction with correct sequenceId');
	it.todo('calls channel.submitAction with the action');
	it.todo('no-ops when gameOver is set');
	it.todo('no-ops when optimisticState is null (not initialized)');
	it.todo('handles non-MoveEntity actions (applies optimistically but returns unchanged state)');
});

describe('receiveResolution', () => {
	it.todo('replaces both serverState and optimisticState with server payload');
	it.todo('clears pendingAction');
	it.todo('works even when no pendingAction exists');
});

describe('receiveRejection', () => {
	it.todo('rolls optimisticState back to serverState');
	it.todo('clears pendingAction');
	it.todo('calls toastStore.show with first error message');
	it.todo('handles empty errors array gracefully');
});

describe('receiveGameOver', () => {
	it.todo('sets gameOver with winner_id and finalState');
	it.todo('updates both serverState and optimisticState');
	it.todo('clears pendingAction');
});
