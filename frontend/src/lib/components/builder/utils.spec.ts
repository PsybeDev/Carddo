import { describe, it, expect } from 'vitest';

import {
	CONDITION_OPERATORS,
	TRIGGER_ACTION_TYPES,
	TRIGGER_PHASES,
	composeTrigger,
	createEmptyRule,
	normalizeRule,
	parseTrigger
} from './utils';

const UUID_V4_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

describe('parseTrigger', () => {
	it('parses on_after_mutate_property', () => {
		expect(parseTrigger('on_after_mutate_property')).toEqual({
			phase: 'on_after_',
			actionType: 'mutate_property',
			selfOnly: false
		});
	});

	it('parses on_before_move_entity', () => {
		expect(parseTrigger('on_before_move_entity')).toEqual({
			phase: 'on_before_',
			actionType: 'move_entity',
			selfOnly: false
		});
	});

	it('parses on_after_mutate_property:self', () => {
		expect(parseTrigger('on_after_mutate_property:self')).toEqual({
			phase: 'on_after_',
			actionType: 'mutate_property',
			selfOnly: true
		});
	});

	it('parses on_before_end_turn:self', () => {
		expect(parseTrigger('on_before_end_turn:self')).toEqual({
			phase: 'on_before_',
			actionType: 'end_turn',
			selfOnly: true
		});
	});

	it('parses on_after_any', () => {
		expect(parseTrigger('on_after_any')).toEqual({
			phase: 'on_after_',
			actionType: 'any',
			selfOnly: false
		});
	});

	it('parses on_before_any:self', () => {
		expect(parseTrigger('on_before_any:self')).toEqual({
			phase: 'on_before_',
			actionType: 'any',
			selfOnly: true
		});
	});

	it('parses on_after_spawn_entity', () => {
		expect(parseTrigger('on_after_spawn_entity')).toEqual({
			phase: 'on_after_',
			actionType: 'spawn_entity',
			selfOnly: false
		});
	});
});

describe('composeTrigger', () => {
	it('composes mutate_property trigger without self scope', () => {
		expect(composeTrigger('on_after_', 'mutate_property', false)).toBe('on_after_mutate_property');
	});

	it('composes move_entity trigger with self scope', () => {
		expect(composeTrigger('on_before_', 'move_entity', true)).toBe('on_before_move_entity:self');
	});

	it('composes any trigger without self scope', () => {
		expect(composeTrigger('on_after_', 'any', false)).toBe('on_after_any');
	});
});

describe('trigger roundtrip', () => {
	it.each([
		'on_after_mutate_property',
		'on_before_move_entity:self',
		'on_after_any',
		'on_before_spawn_entity',
		'on_after_end_turn:self'
	])('roundtrips %s', (trigger) => {
		const parsed = parseTrigger(trigger);
		expect(composeTrigger(parsed.phase, parsed.actionType, parsed.selfOnly)).toBe(trigger);
	});
});

describe('normalizeRule', () => {
	it('returns complete rule unchanged for core fields', () => {
		const complete = {
			id: '7f76af4a-dc6b-4fa9-8f0e-70ddf7caa731',
			name: 'My Rule',
			trigger: 'on_before_move_entity:self',
			conditions: [{ left: 'a', op: '==', right: 1 }],
			actions: [{ type: 'end_turn' }],
			cancels: true
		};

		expect(normalizeRule(complete)).toEqual(complete);
	});

	it('fills defaults for empty object', () => {
		const normalized = normalizeRule({});

		expect(normalized.id).toMatch(UUID_V4_REGEX);
		expect(normalized.name).toBe('');
		expect(normalized.trigger).toBe('on_after_mutate_property');
		expect(normalized.conditions).toEqual([]);
		expect(normalized.actions).toEqual([]);
		expect(normalized.cancels).toBe(false);
	});

	it('preserves partial values and fills missing defaults', () => {
		const normalized = normalizeRule({ trigger: 'on_before_any', cancels: true });

		expect(normalized.trigger).toBe('on_before_any');
		expect(normalized.cancels).toBe(true);
		expect(normalized.id).toMatch(UUID_V4_REGEX);
		expect(normalized.name).toBe('');
		expect(normalized.conditions).toEqual([]);
		expect(normalized.actions).toEqual([]);
	});

	it('replaces empty id string with UUID', () => {
		const normalized = normalizeRule({ id: '' });

		expect(normalized.id).toMatch(UUID_V4_REGEX);
	});

	it('replaces non-array conditions with empty array', () => {
		const normalized = normalizeRule({ conditions: 'not_an_array' });

		expect(normalized.conditions).toEqual([]);
	});

	it('replaces undefined cancels with false', () => {
		const normalized = normalizeRule({ cancels: undefined });

		expect(normalized.cancels).toBe(false);
	});

	it('replaces null cancels with false', () => {
		const normalized = normalizeRule({ cancels: null });

		expect(normalized.cancels).toBe(false);
	});
});

describe('createEmptyRule', () => {
	it('returns required EcaRule fields with expected defaults', () => {
		const rule = createEmptyRule();

		expect(Object.keys(rule).sort()).toEqual(
			['actions', 'cancels', 'conditions', 'id', 'name', 'trigger'].sort()
		);
		expect(rule.id).toMatch(UUID_V4_REGEX);
		expect(rule.trigger).toBe('on_after_mutate_property');
		expect(rule.conditions).toEqual([]);
		expect(rule.actions).toEqual([]);
		expect(rule.cancels).toBe(false);
		expect(rule.name).toBe('');
	});

	it('generates different ids for separate calls', () => {
		const first = createEmptyRule();
		const second = createEmptyRule();

		expect(first.id).not.toBe(second.id);
	});
});

describe('CONDITION_OPERATORS', () => {
	it('matches engine operators and labels', () => {
		expect(CONDITION_OPERATORS).toHaveLength(6);
		expect(CONDITION_OPERATORS.map((op) => op.value)).toEqual(['==', '!=', '<', '<=', '>', '>=']);
		expect(CONDITION_OPERATORS.every((op) => op.label.trim().length > 0)).toBe(true);
	});
});

describe('TRIGGER_ACTION_TYPES', () => {
	it('covers all engine action_type_str values', () => {
		expect(TRIGGER_ACTION_TYPES).toHaveLength(5);
		expect(TRIGGER_ACTION_TYPES.map((type) => type.value)).toEqual([
			'mutate_property',
			'move_entity',
			'spawn_entity',
			'end_turn',
			'any'
		]);
	});
});

describe('TRIGGER_PHASES', () => {
	it('contains the two supported trigger phases', () => {
		expect(TRIGGER_PHASES).toHaveLength(2);
		expect(TRIGGER_PHASES.map((phase) => phase.value)).toEqual(['on_before_', 'on_after_']);
	});
});
