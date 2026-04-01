import type { SchemaRule, ConditionOperator } from '$lib/types/rules';
import { CONDITION_OPERATORS } from '$lib/types/rules';

export type ValidationError = {
	ruleId: string;
	ruleName: string;
	field: string;
	message: string;
};

export type ValidationResult = {
	valid: boolean;
	errors: ValidationError[];
};

function isPlainObject(value: unknown): value is Record<string, unknown> {
	return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validateCondition(
	condition: unknown,
	ruleId: string,
	ruleName: string,
	index: number
): ValidationError[] {
	const errors: ValidationError[] = [];
	const prefix = `Condition[${index}]`;

	if (!isPlainObject(condition)) {
		errors.push({ ruleId, ruleName, field: `${prefix}`, message: 'Condition must be an object.' });
		return errors;
	}

	const c = condition as Record<string, unknown>;

	if (typeof c.target !== 'string' || !c.target) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}.target`,
			message: 'Condition target is required.'
		});
	}
	if (typeof c.property !== 'string' || !c.property) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}.property`,
			message: 'Condition property is required.'
		});
	}
	if (!CONDITION_OPERATORS.includes(c.operator as ConditionOperator)) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}.operator`,
			message: `Condition operator must be one of: ${[...CONDITION_OPERATORS].join(', ')}.`
		});
	}
	if (typeof c.value !== 'number' || !Number.isFinite(c.value)) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}.value`,
			message: 'Condition value must be a finite number.'
		});
	}

	return errors;
}

function validateAction(
	action: unknown,
	ruleId: string,
	ruleName: string,
	index: number
): ValidationError[] {
	const errors: ValidationError[] = [];
	const prefix = `Action[${index}]`;

	if (action === 'EndTurn') {
		return errors;
	}

	if (!isPlainObject(action)) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}`,
			message: 'Action must be an object or "EndTurn".'
		});
		return errors;
	}

	const a = action as Record<string, unknown>;
	const keys = Object.keys(a);

	if (keys.length === 0) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}`,
			message: 'Action object must not be empty.'
		});
		return errors;
	}

	const variant = keys[0] as string;
	const payload = a[variant];

	if (!isPlainObject(payload)) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}.${variant}`,
			message: `Action payload for "${variant}" must be an object.`
		});
		return errors;
	}

	const p = payload as Record<string, unknown>;

	if (variant === 'MutateProperty') {
		if (typeof p.target_id !== 'string' || !p.target_id) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MutateProperty.target_id`,
				message: 'MutateProperty target_id is required.'
			});
		}
		if (typeof p.property !== 'string' || !p.property) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MutateProperty.property`,
				message: 'MutateProperty property is required.'
			});
		}
		if (typeof p.delta !== 'number' || !Number.isFinite(p.delta)) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MutateProperty.delta`,
				message: 'MutateProperty delta must be a finite number.'
			});
		}
	} else if (variant === 'MoveEntity') {
		if (typeof p.entity_id !== 'string' || !p.entity_id) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MoveEntity.entity_id`,
				message: 'MoveEntity entity_id is required.'
			});
		}
		if (typeof p.from_zone !== 'string' || !p.from_zone) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MoveEntity.from_zone`,
				message: 'MoveEntity from_zone is required.'
			});
		}
		if (typeof p.to_zone !== 'string' || !p.to_zone) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MoveEntity.to_zone`,
				message: 'MoveEntity to_zone is required.'
			});
		}
		if (
			p.index !== null &&
			(typeof p.index !== 'number' || !Number.isFinite(p.index) || p.index < 0)
		) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MoveEntity.index`,
				message: 'MoveEntity index must be null or a non-negative number.'
			});
		}
	} else if (variant === 'SpawnEntity') {
		if (!isPlainObject(p.entity)) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.SpawnEntity.entity`,
				message: 'SpawnEntity entity must be an object.'
			});
		}
		if (typeof p.zone_id !== 'string' || !p.zone_id) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.SpawnEntity.zone_id`,
				message: 'SpawnEntity zone_id is required.'
			});
		}
	} else {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}`,
			message: `Unknown action variant "${variant}". Expected: MutateProperty, MoveEntity, SpawnEntity, or "EndTurn".`
		});
	}

	return errors;
}

function validateRule(rule: unknown): ValidationError[] {
	const errors: ValidationError[] = [];

	if (!isPlainObject(rule)) {
		errors.push({ ruleId: '?', ruleName: '?', field: 'rule', message: 'Rule must be an object.' });
		return errors;
	}

	const r = rule as Record<string, unknown>;
	const id = typeof r.id === 'string' && r.id ? r.id : '?';
	const name = typeof r.name === 'string' ? r.name : '(unnamed)';

	if (typeof r.id !== 'string' || !r.id) {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'id',
			message: 'Rule must have a non-empty id.'
		});
	}

	if (typeof r.name !== 'string') {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'name',
			message: 'Rule must have a string name.'
		});
	}

	if (typeof r.trigger !== 'string' || !r.trigger) {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'trigger',
			message: 'Rule must have a trigger string.'
		});
	} else if (
		!/^on_(?:before|after)_(?:mutate_property|move_entity|spawn_entity|end_turn|any)(?::self)?$/.test(
			r.trigger
		)
	) {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'trigger',
			message: `Invalid trigger format "${r.trigger}". Expected: "on_<before|after>_<action_type>" with optional ":self".`
		});
	}

	if (!Array.isArray(r.conditions)) {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'conditions',
			message: 'conditions must be an array.'
		});
	} else {
		for (let i = 0; i < r.conditions.length; i++) {
			errors.push(...validateCondition(r.conditions[i], id, name, i));
		}
	}

	if (!Array.isArray(r.actions)) {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'actions',
			message: 'actions must be an array.'
		});
	} else if (r.actions.length === 0) {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'actions',
			message: 'Rule must have at least one action.'
		});
	} else {
		for (let i = 0; i < r.actions.length; i++) {
			errors.push(...validateAction(r.actions[i], id, name, i));
		}
	}

	if (typeof r.cancels !== 'boolean') {
		errors.push({
			ruleId: id,
			ruleName: name,
			field: 'cancels',
			message: 'Rule must have a boolean cancels field.'
		});
	}

	return errors;
}

export function validateRuleSet(rules: unknown[]): ValidationResult {
	const errors = rules.flatMap((rule) => validateRule(rule));
	return { valid: errors.length === 0, errors };
}

export function getRuleErrors(rules: SchemaRule[]): Map<string, ValidationError[]> {
	const result = validateRuleSet(rules);
	const byRule = new Map<string, ValidationError[]>();

	for (const error of result.errors) {
		const existing = byRule.get(error.ruleId) ?? [];
		existing.push(error);
		byRule.set(error.ruleId, existing);
	}

	return byRule;
}
