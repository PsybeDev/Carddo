import type { GameState, Action } from '$lib/types/ditto.generated';

type WasmModule = typeof import('ditto_wasm');

let wasmModule: WasmModule | null = null;
let initPromise: Promise<void> | null = null;

export async function initWasm(): Promise<void> {
	if (wasmModule) return;
	if (initPromise) {
		await initPromise;
		return;
	}

	initPromise = (async () => {
		const mod = await import('ditto_wasm');
		await mod.default();
		wasmModule = mod;
	})();

	try {
		await initPromise;
	} catch {
		initPromise = null;
		throw new Error('Failed to initialize WASM module');
	}
}

export function isWasmReady(): boolean {
	return wasmModule !== null;
}

export type ValidationResult = { ok: true } | { ok: false; message: string };

export async function validateMove(
	publicState: GameState,
	action: Action
): Promise<ValidationResult> {
	if (!wasmModule) {
		try {
			await initWasm();
		} catch {
			return { ok: false, message: 'Game engine not ready' };
		}
	}

	if (!wasmModule) {
		return { ok: false, message: 'Game engine not ready' };
	}

	try {
		wasmModule.client_validate_move(publicState, action);
		return { ok: true };
	} catch (err: unknown) {
		const message = err instanceof Error ? err.message : String(err);
		return { ok: false, message };
	}
}
