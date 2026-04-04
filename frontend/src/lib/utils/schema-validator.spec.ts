import { describe, it, expect } from 'vitest';
import { validateRuleSet, getRuleErrors } from './schema-validator';
import type { SchemaRule } from '$lib/types/rules';

const validRule: SchemaRule = {
	id: 'rule-1',
	name: 'Thorns',
	trigger: 'on_after_mutate_property:self',
	conditions: [{ target: 'self', property: 'health', operator: '<=', value: 0 }],
	actions: [{ MutateProperty: { target_id: 'self', property: 'defense', delta: 3 } }],
	cancels: false
};

describe('validateRuleSet', () => {
	it('returns valid for a complete rule with all required fields', () => {
		const result = validateRuleSet([validRule]);
		expect(result.valid).toBe(true);
		expect(result.errors).toEqual([]);
	});

	it('returns valid for rule with EndTurn action', () => {
		const result = validateRuleSet([{ ...validRule, actions: ['EndTurn'] }]);
		expect(result.valid).toBe(true);
	});

	it('returns valid for MoveEntity action', () => {
		const result = validateRuleSet([
			{
				...validRule,
				trigger: 'on_after_move_entity',
				conditions: [],
				actions: [
					{ MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'graveyard', index: null } }
				]
			}
		]);
		expect(result.valid).toBe(true);
	});

	it('returns valid for SpawnEntity action with empty entity', () => {
		const result = validateRuleSet([
			{
				...validRule,
				trigger: 'on_after_spawn_entity',
				conditions: [],
				actions: [{ SpawnEntity: { entity: {}, zone_id: 'battlefield' } }]
			}
		]);
		expect(result.valid).toBe(true);
	});

	it('returns error for SpawnEntity with non-object entity', () => {
		const result = validateRuleSet([
			{
				...validRule,
				trigger: 'on_after_spawn_entity',
				conditions: [],
				actions: [{ SpawnEntity: { entity: 'not-an-object', zone_id: 'bf' } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('entity'))).toBe(true);
	});

	it('returns valid for rule with all condition operators', () => {
		const operators = ['==', '!=', '<', '<=', '>', '>='] as const;
		const result = validateRuleSet([
			{
				...validRule,
				conditions: operators.map((op, i) => ({
					target: 'self',
					property: 'hp',
					operator: op,
					value: i
				}))
			}
		]);
		expect(result.valid).toBe(true);
	});

	it('returns valid for rule with cancels true', () => {
		const result = validateRuleSet([{ ...validRule, cancels: true }]);
		expect(result.valid).toBe(true);
	});

	it('returns error for missing rule id', () => {
		const result = validateRuleSet([{ ...validRule, id: '' }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field === 'id')).toBe(true);
	});

	it('returns error for missing trigger', () => {
		const result = validateRuleSet([{ ...validRule, trigger: '' }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field === 'trigger')).toBe(true);
	});

	it('returns error for invalid trigger format', () => {
		const result = validateRuleSet([{ ...validRule, trigger: 'on_play' }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field === 'trigger')).toBe(true);
	});

	it('returns error for non-array conditions', () => {
		const result = validateRuleSet([{ ...validRule, conditions: 'not-an-array' }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field === 'conditions')).toBe(true);
	});

	it('returns error for non-array actions', () => {
		const result = validateRuleSet([{ ...validRule, actions: null }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field === 'actions')).toBe(true);
	});

	it('returns error for empty actions array', () => {
		const result = validateRuleSet([{ ...validRule, actions: [] }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.message.includes('at least one action'))).toBe(true);
	});

	it('returns error for condition missing target', () => {
		const result = validateRuleSet([
			{
				...validRule,
				conditions: [{ property: 'health', operator: '<=', value: 0 }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('Condition'))).toBe(true);
	});

	it('returns valid for condition with "!=" operator', () => {
		const result = validateRuleSet([
			{
				...validRule,
				conditions: [{ target: 'self', property: 'hp', operator: '!=', value: 0 }]
			}
		]);
		expect(result.valid).toBe(true);
	});

	it('returns error for condition with non-finite value', () => {
		const result = validateRuleSet([
			{
				...validRule,
				conditions: [{ target: 'self', property: 'hp', operator: '<=', value: Infinity }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('value'))).toBe(true);
	});

	it('returns error for condition with decimal value', () => {
		const result = validateRuleSet([
			{
				...validRule,
				conditions: [{ target: 'self', property: 'hp', operator: '<=', value: 1.5 }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('value'))).toBe(true);
	});

	it('returns error for condition with value outside i32 range', () => {
		const result = validateRuleSet([
			{
				...validRule,
				conditions: [{ target: 'self', property: 'hp', operator: '<=', value: 2147483648 }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('value'))).toBe(true);
	});

	it('returns error for MutateProperty missing target_id', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ MutateProperty: { property: 'hp', delta: 1 } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('target_id'))).toBe(true);
	});

	it('returns error for MutateProperty delta with decimal', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ MutateProperty: { target_id: 'self', property: 'hp', delta: 1.5 } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('delta'))).toBe(true);
	});

	it('returns error for MutateProperty delta outside i32 range', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ MutateProperty: { target_id: 'self', property: 'hp', delta: -2147483649 } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('delta'))).toBe(true);
	});

	it('returns error for MoveEntity with negative index', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ MoveEntity: { entity_id: 'e1', from_zone: 'h', to_zone: 'g', index: -1 } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('index'))).toBe(true);
	});

	it('returns valid for MoveEntity with omitted index', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'bf' } }]
			}
		]);
		expect(result.valid).toBe(true);
	});

	it('returns error for MoveEntity with float index', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ MoveEntity: { entity_id: 'e1', from_zone: 'h', to_zone: 'g', index: 1.5 } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field.includes('index'))).toBe(true);
	});

	it('returns error for unknown action variant', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [{ DrawCard: { count: 1 } }]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.message.includes('Unknown action variant'))).toBe(true);
	});

	it('returns error for action with multiple keys', () => {
		const result = validateRuleSet([
			{
				...validRule,
				actions: [
					{
						MutateProperty: { target_id: 'self', property: 'hp', delta: 1 },
						EndTurn: null
					}
				]
			}
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.message.includes('exactly one variant'))).toBe(true);
	});

	it('returns error for non-boolean cancels', () => {
		const result = validateRuleSet([{ ...validRule, cancels: 'yes' }]);
		expect(result.valid).toBe(false);
		expect(result.errors.some((e) => e.field === 'cancels')).toBe(true);
	});

	it('returns errors for multiple rules with mixed validity', () => {
		const result = validateRuleSet([
			validRule,
			{ ...validRule, id: 'bad-rule', trigger: '', actions: [] }
		]);
		expect(result.valid).toBe(false);
		expect(result.errors.length).toBeGreaterThan(1);
	});

	it('handles completely non-object rule', () => {
		const result = validateRuleSet([null]);
		expect(result.valid).toBe(false);
		expect(result.errors.length).toBeGreaterThan(0);
	});

	it('handles primitive rule input', () => {
		const result = validateRuleSet([42]);
		expect(result.valid).toBe(false);
	});

	it('returns empty errors for empty rules array', () => {
		const result = validateRuleSet([]);
		expect(result.valid).toBe(true);
		expect(result.errors).toEqual([]);
	});
});

describe('getRuleErrors', () => {
	it('groups errors by rule id', () => {
		const result = getRuleErrors([validRule, { ...validRule, id: 'rule-2', trigger: '' }]);
		expect(result.has('rule-1')).toBe(false);
		expect(result.has('rule-2')).toBe(true);
		const rule2Errors = result.get('rule-2')!;
		expect(rule2Errors.some((e) => e.field === 'trigger')).toBe(true);
	});

	it('returns empty map for valid rules', () => {
		const result = getRuleErrors([validRule]);
		expect(result.size).toBe(0);
	});
});
