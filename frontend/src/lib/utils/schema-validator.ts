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

const I32_MIN = -2147483648;
const I32_MAX = 2147483647;

function isI32(value: unknown): boolean {
	return (
		typeof value === 'number' && Number.isInteger(value) && value >= I32_MIN && value <= I32_MAX
	);
}

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
	if (!isI32(c.value)) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}.value`,
			message: 'Condition value must be a 32-bit integer.'
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

	if (keys.length > 1) {
		errors.push({
			ruleId,
			ruleName,
			field: `${prefix}`,
			message: 'Action object must represent exactly one variant.'
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
		if (!isI32(p.delta)) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MutateProperty.delta`,
				message: 'MutateProperty delta must be a 32-bit integer.'
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
			p.index !== undefined &&
			p.index !== null &&
			(typeof p.index !== 'number' || !Number.isSafeInteger(p.index) || p.index < 0)
		) {
			errors.push({
				ruleId,
				ruleName,
				field: `${prefix}.MoveEntity.index`,
				message: 'MoveEntity index may be omitted, null, or a non-negative integer.'
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
		} else {
			const entity = p.entity as Record<string, unknown>;
			if (typeof entity.id !== 'string' || !entity.id) {
				errors.push({
					ruleId,
					ruleName,
					field: `${prefix}.SpawnEntity.entity.id`,
					message: 'SpawnEntity entity.id is required.'
				});
			}
			if (typeof entity.template_id !== 'string' || !entity.template_id) {
				errors.push({
					ruleId,
					ruleName,
					field: `${prefix}.SpawnEntity.entity.template_id`,
					message: 'SpawnEntity entity.template_id is required.'
				});
			}
			if (typeof entity.owner_id !== 'string' || !entity.owner_id) {
				errors.push({
					ruleId,
					ruleName,
					field: `${prefix}.SpawnEntity.entity.owner_id`,
					message: 'SpawnEntity entity.owner_id is required.'
				});
			}
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

function validateRule(rule: unknown, index: number): ValidationError[] {
	const errors: ValidationError[] = [];
	const fallbackId = `?rule[${index}]`;

	if (!isPlainObject(rule)) {
		errors.push({
			ruleId: fallbackId,
			ruleName: '?',
			field: 'rule',
			message: 'Rule must be an object.'
		});
		return errors;
	}

	const r = rule as Record<string, unknown>;
	const rawId = typeof r.id === 'string' ? r.id : '';
	const id = rawId || fallbackId;
	const name = typeof r.name === 'string' ? r.name : '(unnamed)';

	if (!rawId) {
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
	const errors = rules.flatMap((rule, i) => validateRule(rule, i));
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
