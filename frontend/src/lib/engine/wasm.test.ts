import type { GameState, Action } from '../types/ditto.generated';
import type { ValidationResult } from '../engine/wasm';

import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockInit = vi.fn().mockResolvedValue(undefined);
const mockClientValidateMove = vi.fn();

vi.mock('ditto_wasm', () => ({
	default: mockInit,
	client_validate_move: mockClientValidateMove
}));

describe('wasm loader', () => {
	let initWasm: () => Promise<void>;
	let isWasmReady: () => boolean;
	let validateMove: (state: GameState, action: Action) => Promise<ValidationResult>;

	beforeEach(async () => {
		vi.resetModules();
		mockInit.mockClear();
		mockInit.mockResolvedValue(undefined);
		mockClientValidateMove.mockClear();

		vi.doMock('ditto_wasm', () => ({
			default: mockInit,
			client_validate_move: mockClientValidateMove
		}));

		const mod = await import('../engine/wasm');
		initWasm = mod.initWasm;
		isWasmReady = mod.isWasmReady;
		validateMove = mod.validateMove;
	});

	describe('initWasm', () => {
		it('calls the underlying init() exactly once when called once', async () => {
			await initWasm();
			expect(mockInit).toHaveBeenCalledTimes(1);
		});

		it('calls init() exactly once when called multiple times sequentially', async () => {
			await initWasm();
			await initWasm();
			await initWasm();
			expect(mockInit).toHaveBeenCalledTimes(1);
		});

		it('calls init() exactly once when called concurrently', async () => {
			await Promise.all([initWasm(), initWasm(), initWasm()]);
			expect(mockInit).toHaveBeenCalledTimes(1);
		});

		it('isWasmReady returns false before init', () => {
			expect(isWasmReady()).toBe(false);
		});

		it('isWasmReady returns true after successful init', async () => {
			await initWasm();
			expect(isWasmReady()).toBe(true);
		});

		it('isWasmReady returns false after init failure', async () => {
			mockInit.mockRejectedValueOnce(new Error('WASM load failed'));
			await expect(initWasm()).rejects.toThrow('Failed to initialize WASM module');
			expect(isWasmReady()).toBe(false);
		});

		it('allows retry after init failure', async () => {
			mockInit.mockRejectedValueOnce(new Error('first attempt failed'));
			await expect(initWasm()).rejects.toThrow();

			mockInit.mockResolvedValueOnce(undefined);
			await initWasm();
			expect(mockInit).toHaveBeenCalledTimes(2);
			expect(isWasmReady()).toBe(true);
		});
	});

	describe('validateMove', () => {
		const mockState = {
			entities: {},
			zones: {},
			event_queue: [],
			pending_animations: [],
			stack_order: 'Fifo' as const,
			state_checks: []
		};
		const mockAction = 'EndTurn' as const;

		it('auto-initializes WASM if not ready and returns { ok: true } on valid move', async () => {
			mockClientValidateMove.mockReturnValue(undefined);
			const result = await validateMove(mockState, mockAction);
			expect(result).toEqual({ ok: true });
			expect(mockInit).toHaveBeenCalledTimes(1);
		});

		it('returns { ok: false, message } when client_validate_move throws', async () => {
			mockClientValidateMove.mockImplementation(() => {
				throw new Error('invalid move: entity not in zone');
			});
			await initWasm();
			const result = await validateMove(mockState, mockAction);
			expect(result).toEqual({ ok: false, message: 'invalid move: entity not in zone' });
		});

		it('returns { ok: false, message } when WASM fails to initialize', async () => {
			mockInit.mockRejectedValueOnce(new Error('WASM failed to load'));
			const result = await validateMove(mockState, mockAction);
			expect(result).toEqual({ ok: false, message: 'Game engine not ready' });
		});

		it('passes JS objects directly to client_validate_move (not JSON strings)', async () => {
			mockClientValidateMove.mockReturnValue(undefined);
			await initWasm();
			await validateMove(mockState, mockAction);
			expect(mockClientValidateMove).toHaveBeenCalledWith(mockState, mockAction);
		});

		it('reuses initialized WASM on subsequent calls', async () => {
			mockClientValidateMove.mockReturnValue(undefined);
			await initWasm();
			await validateMove(mockState, mockAction);
			await validateMove(mockState, mockAction);
			expect(mockInit).toHaveBeenCalledTimes(1);
			expect(mockClientValidateMove).toHaveBeenCalledTimes(2);
		});
	});
});
