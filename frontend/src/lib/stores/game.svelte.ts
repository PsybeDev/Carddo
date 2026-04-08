import type { Action, GameState } from '$lib/types/ditto.generated';

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
