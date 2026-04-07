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
	let validateMove: (state: GameState, action: Action) => ValidationResult;

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

		it('returns { ok: true } when client_validate_move does not throw', async () => {
			mockClientValidateMove.mockReturnValue(undefined);
			await initWasm();
			const result = validateMove(mockState, mockAction);
			expect(result).toEqual({ ok: true });
		});

		it('returns { ok: false, message } when client_validate_move throws', async () => {
			mockClientValidateMove.mockImplementation(() => {
				throw new Error('invalid move: entity not in zone');
			});
			await initWasm();
			const result = validateMove(mockState, mockAction);
			expect(result).toEqual({ ok: false, message: 'invalid move: entity not in zone' });
		});

		it('throws "Wasm not initialised" when called before initWasm()', () => {
			expect(() => validateMove(mockState, mockAction)).toThrow('Wasm not initialised');
		});
	});
});
