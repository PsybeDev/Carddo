import { describe, it, expect, beforeEach, vi } from 'vitest';

vi.mock('$lib/stores/toast.svelte', () => ({
	toastStore: { show: vi.fn() }
}));

import { applyActionOptimistically, gameStore } from '$lib/stores/game.svelte';
import { toastStore } from '$lib/stores/toast.svelte';
import type { GameChannel } from '$lib/api/channel.svelte';
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
	const mockChannel = {
		submitAction: vi.fn(),
		currentSequenceId: 0
	} as unknown as GameChannel;

	beforeEach(() => {
		gameStore.reset();
		vi.clearAllMocks();
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		(mockChannel as any).currentSequenceId = 0;
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		(mockChannel.submitAction as any).mockImplementation(() => {
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
			(mockChannel as any).currentSequenceId += 1;
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
			return (mockChannel as any).currentSequenceId;
		});
	});

	it('applies optimistic MoveEntity to optimisticState', () => {
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

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove(action, mockChannel);

		expect(gameStore.optimisticState?.zones['battlefield'].entities).toContain('e1');
		expect(gameStore.optimisticState?.zones['hand'].entities).not.toContain('e1');
	});

	it('does not modify serverState', () => {
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

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove(action, mockChannel);

		expect(gameStore.serverState?.zones['hand'].entities).toContain('e1');
	});

	it('sets pendingAction with correct sequenceId', () => {
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

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove(action, mockChannel);

		expect(gameStore.pendingAction).not.toBeNull();
		expect(gameStore.pendingAction?.sequenceId).toBe(1);
		expect(gameStore.pendingAction?.action).toEqual(action);
	});

	it('calls channel.submitAction with the action', () => {
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

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove(action, mockChannel);

		expect(mockChannel.submitAction).toHaveBeenCalledTimes(1);
		expect(mockChannel.submitAction).toHaveBeenCalledWith(action);
	});

	it.todo('no-ops when gameOver is set');

	it('no-ops when optimisticState is null (not initialized)', () => {
		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		gameStore.attemptMove(action, mockChannel);

		expect(mockChannel.submitAction).not.toHaveBeenCalled();
		expect(gameStore.optimisticState).toBeNull();
	});

	it('handles non-MoveEntity actions (applies optimistically but returns unchanged state)', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove('EndTurn', mockChannel);

		expect(mockChannel.submitAction).toHaveBeenCalledWith('EndTurn');
		expect(gameStore.optimisticState).toEqual(gameStore.serverState);
		expect(gameStore.pendingAction).not.toBeNull();
		expect(gameStore.pendingAction?.sequenceId).toBe(1);
		expect(gameStore.pendingAction?.action).toEqual('EndTurn');
	});

	it('no-ops when pendingAction already exists (blocks concurrent moves)', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [], null)
			}
		};

		const action1: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};
		const action2: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'battlefield', to_zone: 'hand', index: null }
		};

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove(action1, mockChannel);
		const firstPending = gameStore.pendingAction;

		gameStore.attemptMove(action2, mockChannel);

		expect(gameStore.pendingAction).toEqual(firstPending);
		expect(gameStore.pendingAction?.action).toEqual(action1);
		expect(mockChannel.submitAction).toHaveBeenCalledTimes(1);
		expect(toastStore.show).toHaveBeenCalledWith('Action already pending - please wait', 'info');
	});

	it('no-ops when submitAction returns null (channel not available)', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [], null)
			}
		};

		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		(mockChannel.submitAction as any).mockReturnValue(null);

		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};

		gameStore.initGame(state, 'p1');
		gameStore.attemptMove(action, mockChannel);

		expect(gameStore.optimisticState).toEqual(state);
		expect(gameStore.pendingAction).toBeNull();
	});
});

describe('receiveResolution', () => {
	beforeEach(() => {
		gameStore.reset();
	});

	it('replaces both serverState and optimisticState with server payload', () => {
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
		gameStore.receiveResolution(stateB);

		expect(gameStore.serverState).toEqual(stateB);
		expect(gameStore.optimisticState).toEqual(stateB);
	});

	it('clears pendingAction', () => {
		const state = makeBaseState();

		gameStore.initGame(state, 'p1');
		gameStore.receiveResolution(state);

		expect(gameStore.pendingAction).toBeNull();
	});

	it('works even when no pendingAction exists', () => {
		const state = makeBaseState();

		gameStore.initGame(state, 'p1');

		expect(() => gameStore.receiveResolution(state)).not.toThrow();
		expect(gameStore.optimisticState).toEqual(state);
	});
});

describe('receiveRejection', () => {
	beforeEach(() => {
		gameStore.reset();
		vi.clearAllMocks();
	});

	it('rolls optimisticState back to serverState', () => {
		const stateA: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { hand: makeZone('hand', ['e1'], 'p1') }
		};

		gameStore.initGame(stateA, 'p1');
		gameStore.receiveRejection({
			client_sequence_id: 1,
			errors: [{ message: 'Invalid move', code: 'invalid_move' }]
		});

		expect(gameStore.optimisticState).toEqual(gameStore.serverState);
	});

	it('clears pendingAction', () => {
		const state = makeBaseState();

		gameStore.initGame(state, 'p1');
		gameStore.receiveRejection({
			client_sequence_id: 1,
			errors: [{ message: 'Invalid move', code: 'invalid_move' }]
		});

		expect(gameStore.pendingAction).toBeNull();
	});

	it('calls toastStore.show with first error message', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [], null)
			}
		};

		gameStore.initGame(state, 'p1');

		const mockChannel = {
			submitAction: vi.fn().mockReturnValue(1),
			currentSequenceId: 1
		} as unknown as GameChannel;
		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};
		gameStore.attemptMove(action, mockChannel);

		gameStore.receiveRejection({
			client_sequence_id: 1,
			errors: [{ message: 'Invalid move', code: 'invalid_move' }]
		});

		expect(toastStore.show).toHaveBeenCalledWith('Invalid move', 'error');
	});

	it('handles empty errors array gracefully', () => {
		const state: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [], null)
			}
		};
		gameStore.initGame(state, 'p1');

		const mockChannel = {
			submitAction: vi.fn().mockReturnValue(1),
			currentSequenceId: 1
		} as unknown as GameChannel;
		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};
		gameStore.attemptMove(action, mockChannel);

		gameStore.receiveRejection({
			client_sequence_id: 1,
			errors: []
		});

		expect(toastStore.show).toHaveBeenCalledWith('Action rejected', 'error');
	});

	it('ignores rejection with mismatched sequenceId (stale rejection)', () => {
		const stateA: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: {
				hand: makeZone('hand', ['e1'], 'p1'),
				battlefield: makeZone('battlefield', [], null)
			}
		};

		const staleSequenceId = 2;

		gameStore.initGame(stateA, 'p1');

		const mockChannel = {
			submitAction: vi.fn().mockReturnValue(5),
			currentSequenceId: 5
		} as unknown as GameChannel;
		const action: Action = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: null }
		};
		gameStore.attemptMove(action, mockChannel);

		const expectedPending = gameStore.pendingAction;
		const expectedOptimistic = gameStore.optimisticState;

		gameStore.receiveRejection({
			client_sequence_id: staleSequenceId,
			errors: [{ message: 'Old action failed', code: 'old_error' }]
		});

		expect(gameStore.pendingAction).toEqual(expectedPending);
		expect(gameStore.optimisticState).toEqual(expectedOptimistic);
		expect(toastStore.show).not.toHaveBeenCalled();
	});

	it('ignores rejection when no pendingAction exists', () => {
		const state = makeBaseState();
		gameStore.initGame(state, 'p1');

		gameStore.receiveRejection({
			client_sequence_id: 1,
			errors: [{ message: 'Unexpected rejection', code: 'unexpected' }]
		});

		expect(toastStore.show).not.toHaveBeenCalled();
	});
});

describe('receiveGameOver', () => {
	beforeEach(() => {
		gameStore.reset();
	});

	it('sets gameOver with winner_id and finalState', () => {
		const initial = makeBaseState();
		const finalState: GameState = {
			...makeBaseState(),
			entities: { e1: makeEntity('e1') },
			zones: { graveyard: makeZone('graveyard', ['e1'], null) }
		};

		gameStore.initGame(initial, 'p1');
		gameStore.receiveGameOver({ winner_id: 'p1', final_state: finalState });

		expect(gameStore.gameOver).not.toBeNull();
		expect(gameStore.gameOver?.winner_id).toBe('p1');
		expect(gameStore.gameOver?.finalState).toEqual(finalState);
	});

	it('updates both serverState and optimisticState', () => {
		const initial = makeBaseState();
		const finalState: GameState = {
			...makeBaseState(),
			entities: { e2: makeEntity('e2') },
			zones: { battlefield: makeZone('battlefield', ['e2'], null) }
		};

		gameStore.initGame(initial, 'p1');
		gameStore.receiveGameOver({ winner_id: 'p2', final_state: finalState });

		expect(gameStore.serverState).toEqual(finalState);
		expect(gameStore.optimisticState).toEqual(finalState);
	});

	it('clears pendingAction', () => {
		const initial = makeBaseState();
		const finalState = makeBaseState();

		gameStore.initGame(initial, 'p1');
		gameStore.receiveGameOver({ winner_id: 'p1', final_state: finalState });

		expect(gameStore.pendingAction).toBeNull();
	});
});
