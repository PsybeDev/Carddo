import { describe, it, expect } from 'vitest';

import { buildWsUrl, parseGameState } from './channel.svelte';

describe('buildWsUrl', () => {
	it('converts http to ws and appends /socket', () => {
		expect(buildWsUrl('http://localhost:4000')).toBe('ws://localhost:4000/socket');
	});

	it('converts https to wss and appends /socket', () => {
		expect(buildWsUrl('https://example.com')).toBe('wss://example.com/socket');
	});

	it('strips base path and appends /socket', () => {
		expect(buildWsUrl('https://example.com/api')).toBe('wss://example.com/socket');
	});

	it('handles trailing slash', () => {
		expect(buildWsUrl('http://localhost:4000/')).toBe('ws://localhost:4000/socket');
	});

	it('throws descriptive error for empty string', () => {
		expect(() => buildWsUrl('')).toThrow('PUBLIC_API_URL is missing or empty');
	});

	it('throws descriptive error for whitespace-only string', () => {
		expect(() => buildWsUrl('   ')).toThrow('PUBLIC_API_URL is missing or empty');
	});

	it('throws descriptive error for invalid URL', () => {
		expect(() => buildWsUrl('not-a-url')).toThrow('PUBLIC_API_URL is invalid');
	});
});

describe('parseGameState', () => {
	it('parses valid JSON string into GameState object', () => {
		const state = {
			entities: {},
			zones: {},
			event_queue: [],
			pending_animations: [],
			stack_order: 'Fifo',
			state_checks: [],
			turn_ended: false,
			game_over: null
		};
		const result = parseGameState(JSON.stringify(state));
		expect(result).toEqual(state);
	});

	it('returns object with expected GameState shape', () => {
		const state = {
			entities: {
				'abc-123': {
					id: 'abc-123',
					owner_id: 'p1',
					template_id: 'warrior',
					properties: { health: 10, attack: 3 },
					abilities: []
				}
			},
			zones: {
				hand: {
					id: 'hand',
					entities: ['abc-123'],
					visibility: 'OwnerOnly' as const,
					owner_id: 'p1'
				}
			},
			event_queue: [],
			pending_animations: [],
			stack_order: 'Fifo',
			state_checks: []
		};
		const result = parseGameState(JSON.stringify(state));
		expect(result.entities['abc-123'].template_id).toBe('warrior');
		expect(result.zones['hand'].entities).toEqual(['abc-123']);
	});

	it('throws Error for invalid JSON string', () => {
		expect(() => parseGameState('not json')).toThrow('Failed to parse game state');
	});

	it('throws Error for empty string', () => {
		expect(() => parseGameState('')).toThrow('Cannot parse empty state string');
	});
});
