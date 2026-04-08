import type { Action, GameState } from '$lib/types/ditto.generated';
import type { GameChannel } from '$lib/api/channel.svelte';
import { toastStore } from '$lib/stores/toast.svelte';
import type { ActionRejectedPayload } from '$lib/types/channel';

export function applyActionOptimistically(state: GameState, action: Action): GameState {
	if (action === 'EndTurn' || !('MoveEntity' in action)) {
		return structuredClone(state);
	}

	const { entity_id, from_zone, to_zone, index } = action.MoveEntity;

	if (!state.zones[from_zone] || !state.zones[to_zone]) {
		return structuredClone(state);
	}

	if (!state.zones[from_zone].entities.includes(entity_id)) {
		return structuredClone(state);
	}

	const cloned = structuredClone(state);

	cloned.zones[from_zone].entities = cloned.zones[from_zone].entities.filter((id) => id !== entity_id);

	if (index !== null && index !== undefined) {
		cloned.zones[to_zone].entities.splice(index, 0, entity_id);
	} else {
		cloned.zones[to_zone].entities.push(entity_id);
	}

	return cloned;
}

// Module-level reactive state
let serverState = $state<GameState | null>(null);
let optimisticState = $state<GameState | null>(null);
let pendingAction = $state<{ sequenceId: number; action: Action } | null>(null);
let gameOver = $state<{ winner_id: string; finalState: GameState } | null>(null);

// Non-reactive — set once on init, does not need reactivity
let currentPlayerId = '';

export const gameStore = {
	get serverState(): GameState | null {
		return serverState;
	},
	get optimisticState(): GameState | null {
		return optimisticState;
	},
	get pendingAction(): { sequenceId: number; action: Action } | null {
		return pendingAction;
	},
	get currentPlayerId(): string {
		return currentPlayerId;
	},
	get gameOver(): { winner_id: string; finalState: GameState } | null {
		return gameOver;
	},

	initGame(initialState: GameState, playerId: string): void {
		serverState = structuredClone(initialState);
		optimisticState = structuredClone(initialState);
		currentPlayerId = playerId;
		pendingAction = null;
		gameOver = null;
	},

	reset(): void {
		serverState = null;
		optimisticState = null;
		pendingAction = null;
		gameOver = null;
		currentPlayerId = '';
	},

	attemptMove(action: Action, channel: GameChannel): void {
		if (gameOver !== null) return;
		if (optimisticState === null) return;

		optimisticState = applyActionOptimistically(optimisticState, action);

		channel.submitAction(action);

		pendingAction = { sequenceId: channel.currentSequenceId, action };
	},

	receiveResolution(serverPayload: GameState): void {
		serverState = structuredClone(serverPayload);
		optimisticState = structuredClone(serverPayload);
		pendingAction = null;
	},

	receiveRejection(payload: ActionRejectedPayload): void {
		pendingAction = null;
		optimisticState = serverState ? structuredClone(serverState) : null;
		toastStore.show(payload.errors[0]?.message ?? 'Action rejected', 'error');
	},

	receiveGameOver(payload: { winner_id: string; final_state: GameState }): void {
		serverState = structuredClone(payload.final_state);
		optimisticState = structuredClone(payload.final_state);
		gameOver = { winner_id: payload.winner_id, finalState: payload.final_state };
		pendingAction = null;
	}
};
