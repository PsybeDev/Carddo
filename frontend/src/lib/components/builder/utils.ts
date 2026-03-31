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

/** Fills missing fields for backward compat with rules saved before id/name/cancels existed. */
export function normalizeRule(r: Record<string, unknown>): EcaRule {
	return {
		id: typeof r.id === 'string' && r.id ? r.id : crypto.randomUUID(),
		name: typeof r.name === 'string' ? r.name : '',
		trigger: typeof r.trigger === 'string' && r.trigger ? r.trigger : 'on_after_mutate_property',
		conditions: Array.isArray(r.conditions) ? r.conditions : [],
		actions: Array.isArray(r.actions) ? r.actions : [],
		cancels: typeof r.cancels === 'boolean' ? r.cancels : false
	};
}
