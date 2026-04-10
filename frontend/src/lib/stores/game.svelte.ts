import type { Action, GameState } from '$lib/types/ditto.generated';
import type { GameChannel } from '$lib/api/channel.svelte';
import { toastStore } from '$lib/stores/toast.svelte';
import type { ActionRejectedPayload, GameOverPayload } from '$lib/types/channel';

/**
 * Applies an action optimistically to a game state for immediate UI feedback.
 * Returns a deep-cloned state that callers must treat as non-authoritative —
 * it may be rolled back when the authoritative state arrives from the server.
 *
 * @param state - The current GameState to apply the action to
 * @param action - The Action to apply (currently supports MoveEntity and EndTurn)
 * @returns A new GameState with the action applied, or an unmodified clone if the action cannot be applied
 */
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

	cloned.zones[from_zone].entities = cloned.zones[from_zone].entities.filter(
		(id) => id !== entity_id
	);

	if (index !== null && index !== undefined) {
		const maxIndex = cloned.zones[to_zone].entities.length;
		const safeIndex = Math.max(0, Math.min(index, maxIndex));
		cloned.zones[to_zone].entities.splice(safeIndex, 0, entity_id);
	} else {
		cloned.zones[to_zone].entities.push(entity_id);
	}

	return cloned;
}

// Module-level reactive state
let serverState = $state<GameState | null>(null);
let optimisticState = $state<GameState | null>(null);
let pendingAction = $state<{ sequenceId: number; action: Action } | null>(null);
let gameOver = $state<{ winner_id?: string; finalState: GameState } | null>(null);

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
	get gameOver(): { winner_id?: string; finalState: GameState } | null {
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
		if (pendingAction !== null) {
			toastStore.show('Action already pending - please wait', 'info');
			return;
		}

		const sequenceId = channel.submitAction(action);
		if (sequenceId === null) {
			toastStore.show('Unable to send action - connection lost', 'error');
			return;
		}

		optimisticState = applyActionOptimistically(optimisticState, action);
		pendingAction = { sequenceId, action };
	},

	receiveResolution(serverPayload: GameState): void {
		serverState = structuredClone(serverPayload);
		optimisticState = structuredClone(serverPayload);
		pendingAction = null;
	},

	receiveRejection(payload: ActionRejectedPayload): void {
		const isStaleRejection =
			pendingAction === null || pendingAction.sequenceId !== payload.client_sequence_id;
		if (isStaleRejection) return;

		pendingAction = null;
		optimisticState = serverState ? structuredClone(serverState) : null;
		const errorMessage =
			payload.errors && payload.errors.length > 0 ? payload.errors[0].message : 'Action rejected';
		toastStore.show(errorMessage, 'error');
	},

	/**
	 * Handles the end-of-game signal from the server.
	 * Deep-clones final_state to avoid shared mutable references.
	 *
	 * @param payload - Contains winner_id (optional for ties/aborts) and final_state
	 */
	receiveGameOver(payload: GameOverPayload): void {
		let finalState: GameState;
		try {
			finalState = JSON.parse(payload.final_state) as GameState;
		} catch (err) {
			const msg = err instanceof Error ? err.message : 'unknown error';
			toastStore.show(`Failed to parse game over state: ${msg}`, 'error');
			pendingAction = null;
			return;
		}
		serverState = structuredClone(finalState);
		optimisticState = structuredClone(finalState);
		gameOver = {
			winner_id: payload.winner_id,
			finalState: structuredClone(finalState)
		};
		pendingAction = null;
	}
};
