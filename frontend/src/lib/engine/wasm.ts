import init, { client_validate_move } from 'ditto_wasm';
import type { GameState, Action } from '$lib/types/ditto.generated';

let initPromise: Promise<void> | null = null;

export async function initWasm(): Promise<void> {
	if (!initPromise) {
		initPromise = init().then(() => undefined);
	}
	await initPromise;
}

export type ValidationResult = { ok: true } | { ok: false; message: string };

export function validateMove(publicState: GameState, action: Action): ValidationResult {
	if (!initPromise) throw new Error('Wasm not initialised');
	try {
		client_validate_move(publicState, action);
		return { ok: true };
	} catch (err: unknown) {
		const message = err instanceof Error ? err.message : String(err);
		return { ok: false, message };
	}
}
