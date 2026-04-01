import type { ConditionOperator, EcaRule } from '$lib/types/api';

export const TRIGGER_PHASES = [
	{ value: 'on_before_', label: 'Before' },
	{ value: 'on_after_', label: 'After' }
] as const;

export const TRIGGER_ACTION_TYPES = [
	{ value: 'mutate_property', label: 'Mutate Property' },
	{ value: 'move_entity', label: 'Move Entity' },
	{ value: 'spawn_entity', label: 'Spawn Entity' },
	{ value: 'end_turn', label: 'End Turn' },
	{ value: 'any', label: 'Any Action' }
] as const;

export const CONDITION_OPERATORS: ReadonlyArray<{
	value: ConditionOperator;
	label: string;
}> = [
	{ value: '==', label: '=' },
	{ value: '!=', label: '≠' },
	{ value: '<', label: '<' },
	{ value: '<=', label: '≤' },
	{ value: '>', label: '>' },
	{ value: '>=', label: '≥' }
];

export type ParsedTrigger = {
	phase: string;
	actionType: string;
	selfOnly: boolean;
};

/**
 * Decomposes an engine trigger string into its parts.
 *
 *   "on_after_mutate_property"       → { phase: "on_after_",  actionType: "mutate_property", selfOnly: false }
 *   "on_before_move_entity:self"     → { phase: "on_before_", actionType: "move_entity",     selfOnly: true  }
 */
export function parseTrigger(trigger: string): ParsedTrigger {
	const selfOnly = trigger.endsWith(':self');
	const base = selfOnly ? trigger.slice(0, -5) : trigger;
	const phase = base.startsWith('on_before_') ? 'on_before_' : 'on_after_';
	const actionType = base.slice(phase.length) || 'any';
	return { phase, actionType, selfOnly };
}

export function composeTrigger(phase: string, actionType: string, selfOnly: boolean): string {
	return `${phase}${actionType}${selfOnly ? ':self' : ''}`;
}

export function createEmptyRule(): EcaRule {
	return {
		id: crypto.randomUUID(),
		name: '',
		trigger: 'on_after_mutate_property',
		conditions: [],
		actions: [],
		cancels: false
	};
}

const I32_MIN = -2147483648;
const I32_MAX = 2147483647;

export function parseI32(raw: string): number | null {
	if (raw === '') return null;
	const parsed = parseInt(raw, 10);
	if (Number.isNaN(parsed)) return null;
	return Math.max(I32_MIN, Math.min(I32_MAX, parsed));
}

export function parseUsize(raw: string): number | null {
	if (raw === '') return null;
	const parsed = parseInt(raw, 10);
	if (Number.isNaN(parsed) || parsed < 0) return null;
	return Math.floor(parsed);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
	return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Fills missing fields for backward compat with rules saved before id/name/cancels existed. */
export function normalizeRule(r: unknown): EcaRule {
	const obj = isPlainObject(r) ? r : {};
	const rawConditions = Array.isArray(obj.conditions) ? obj.conditions : [];
	const rawActions = Array.isArray(obj.actions) ? obj.actions : [];
	return {
		id: typeof obj.id === 'string' && obj.id ? obj.id : crypto.randomUUID(),
		name: typeof obj.name === 'string' ? obj.name : '',
		trigger:
			typeof obj.trigger === 'string' && obj.trigger ? obj.trigger : 'on_after_mutate_property',
		conditions: rawConditions.filter(isPlainObject) as EcaRule['conditions'],
		actions: rawActions.filter((a) => isPlainObject(a) || a === 'EndTurn') as EcaRule['actions'],
		cancels: typeof obj.cancels === 'boolean' ? obj.cancels : false
	};
}
