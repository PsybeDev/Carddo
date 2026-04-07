import type { GameState } from '$lib/types/ditto.generated';

export function findEntityZone(gameState: GameState, entityId: string): string | null {
	for (const [zoneId, zone] of Object.entries(gameState.zones)) {
		if (zone.entities.includes(entityId)) return zoneId;
	}
	return null;
}

export function stripPrivateState(gameState: GameState, currentPlayerId: string): GameState {
	const cloned = structuredClone(gameState);

	for (const zone of Object.values(cloned.zones)) {
		const isHidden = typeof zone.visibility === 'object' && 'Hidden' in zone.visibility;
		const isOpponentOwnerOnly =
			zone.visibility === 'OwnerOnly' && zone.owner_id !== currentPlayerId;

		if (isHidden || isOpponentOwnerOnly) {
			for (const entityId of zone.entities) {
				delete cloned.entities[entityId];
			}
			zone.entities = [];
		}
	}

	return cloned;
}
