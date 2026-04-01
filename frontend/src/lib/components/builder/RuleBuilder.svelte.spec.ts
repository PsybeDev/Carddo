import { page } from 'vitest/browser';
import { describe, expect, it } from 'vitest';
import { render } from 'vitest-browser-svelte';
import TriggerBlock from './TriggerBlock.svelte';
import ConditionBlock from './ConditionBlock.svelte';
import ActionBlock from './ActionBlock.svelte';
import RuleBuilder from './RuleBuilder.svelte';
import type { EcaAction, EcaCondition, GameConfig, EcaRule } from '$lib/types/api';

const gameConfig: GameConfig = {
	zones: [
		{ name: 'hand', visibility: 'OwnerOnly', capacity: null },
		{ name: 'battlefield', visibility: 'Public', capacity: null },
		{ name: 'graveyard', visibility: 'Public', capacity: null }
	],
	properties: [
		{ name: 'health', default: 20 },
		{ name: 'attack', default: 0 },
		{ name: 'defense', default: 0 }
	],
	rules: [],
	win_conditions: []
};

describe('TriggerBlock', () => {
	it('renders trigger label, dropdown options, and self-only checkbox', async () => {
		render(TriggerBlock, {
			trigger: 'on_after_mutate_property',
			ruleIndex: 0
		});

		await expect.element(page.getByText('When')).toBeInTheDocument();

		const phaseSelect = page.getByLabelText('Rule 1 trigger phase');
		const actionSelect = page.getByLabelText('Rule 1 trigger action');

		await expect.element(phaseSelect).toBeInTheDocument();
		await expect.element(actionSelect).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Before' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'After' })).toBeInTheDocument();

		await expect.element(page.getByRole('option', { name: 'Mutate Property' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Move Entity' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Spawn Entity' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'End Turn' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Any Action' })).toBeInTheDocument();

		await expect.element(page.getByLabelText('Self only')).toBeInTheDocument();
	});

	it('parses initial trigger string into selected values', async () => {
		render(TriggerBlock, {
			trigger: 'on_before_move_entity:self',
			ruleIndex: 0
		});

		await expect.element(page.getByLabelText('Rule 1 trigger phase')).toHaveValue('on_before_');
		await expect.element(page.getByLabelText('Rule 1 trigger action')).toHaveValue('move_entity');
		await expect.element(page.getByLabelText('Self only')).toBeChecked();
	});
});

describe('ConditionBlock', () => {
	it('renders all condition inputs with property and operator options', async () => {
		const condition: EcaCondition = {
			target: 'self',
			property: 'health',
			operator: '==',
			value: 10
		};

		render(ConditionBlock, {
			condition,
			properties: ['health', 'attack', 'defense'],
			conditionIndex: 0,
			ruleIndex: 0,
			onremove: () => {}
		});

		await expect.element(page.getByText('If')).toBeInTheDocument();

		const targetInput = page.getByLabelText('Rule 1 condition 1 target');
		await expect.element(targetInput).toBeInTheDocument();
		await expect.element(targetInput).toHaveAttribute('placeholder', 'Entity ID (e.g. self)');

		await expect.element(page.getByLabelText('Rule 1 condition 1 property')).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'health' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'attack' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'defense' })).toBeInTheDocument();

		await expect.element(page.getByLabelText('Rule 1 condition 1 operator')).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: '=' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: '≠' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: '<' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: '≤' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: '>' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: '≥' })).toBeInTheDocument();

		await expect.element(page.getByLabelText('Rule 1 condition 1 value')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Remove rule 1 condition 1')).toBeInTheDocument();
	});
});

describe('ActionBlock', () => {
	it('renders action section label and type options', async () => {
		const action: EcaAction = {
			MutateProperty: { target_id: 'self', property: 'health', delta: 1 }
		};

		render(ActionBlock, {
			action,
			properties: ['health', 'attack', 'defense'],
			zones: ['hand', 'battlefield', 'graveyard'],
			actionIndex: 0,
			ruleIndex: 0,
			onremove: () => {}
		});

		await expect.element(page.getByText('Then')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 type')).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Mutate Property' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Move Entity' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'Spawn Entity' })).toBeInTheDocument();
		await expect.element(page.getByRole('option', { name: 'End Turn' })).toBeInTheDocument();
	});

	it('renders mutate property variant fields', async () => {
		const action: EcaAction = {
			MutateProperty: { target_id: 'self', property: 'health', delta: 1 }
		};

		render(ActionBlock, {
			action,
			properties: ['health', 'attack', 'defense'],
			zones: ['hand', 'battlefield', 'graveyard'],
			actionIndex: 0,
			ruleIndex: 0,
			onremove: () => {}
		});

		await expect.element(page.getByLabelText('Rule 1 action 1 target')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 property')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 delta')).toBeInTheDocument();
	});

	it('renders move entity variant fields', async () => {
		const action: EcaAction = {
			MoveEntity: { entity_id: 'e1', from_zone: 'hand', to_zone: 'battlefield', index: 0 }
		};

		render(ActionBlock, {
			action,
			properties: ['health', 'attack', 'defense'],
			zones: ['hand', 'battlefield', 'graveyard'],
			actionIndex: 0,
			ruleIndex: 0,
			onremove: () => {}
		});

		await expect.element(page.getByLabelText('Rule 1 action 1 entity')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 from zone')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 to zone')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 index')).toBeInTheDocument();
	});

	it('renders end turn variant with no extra fields', async () => {
		const action: EcaAction = 'EndTurn';

		render(ActionBlock, {
			action,
			properties: ['health', 'attack', 'defense'],
			zones: ['hand', 'battlefield', 'graveyard'],
			actionIndex: 0,
			ruleIndex: 0,
			onremove: () => {}
		});

		await expect.element(page.getByLabelText('Rule 1 action 1 type')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 target')).not.toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 entity')).not.toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 spawn zone')).not.toBeInTheDocument();
	});
});

describe('RuleBuilder', () => {
	it('renders heading, add button, and empty state with no rules', async () => {
		render(RuleBuilder, {
			gameConfig,
			rules: []
		});

		await expect.element(page.getByRole('heading', { name: 'Engine Rules' })).toBeInTheDocument();
		await expect.element(page.getByRole('button', { name: 'Add Rule' })).toBeInTheDocument();
		await expect.element(page.getByText(/No rules yet/)).toBeInTheDocument();
	});

	it('adds and removes a rule block with expected rule structure controls', async () => {
		render(RuleBuilder, {
			gameConfig,
			rules: []
		});

		await page.getByRole('button', { name: 'Add Rule' }).click();

		await expect.element(page.getByLabelText('Rule 1 name')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 trigger phase')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 trigger action')).toBeInTheDocument();
		await expect.element(page.getByRole('button', { name: 'Add Condition' })).toBeInTheDocument();
		await expect.element(page.getByRole('button', { name: 'Add Action' })).toBeInTheDocument();
		await expect.element(page.getByRole('button', { name: 'Delete Rule' })).toBeInTheDocument();

		await page.getByRole('button', { name: 'Delete Rule' }).click();
		await expect.element(page.getByText(/No rules yet/)).toBeInTheDocument();
	});

	it('supports end-to-end rule structure edits within a new rule', async () => {
		render(RuleBuilder, {
			gameConfig,
			rules: []
		});

		await page.getByRole('button', { name: 'Add Rule' }).click();
		await page.getByLabelText('Rule 1 name').fill('Thorns');
		await page.getByRole('button', { name: 'Add Condition' }).click();
		await page.getByRole('button', { name: 'Add Action' }).click();

		await expect.element(page.getByLabelText('Rule 1 condition 1 target')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 action 1 type')).toBeInTheDocument();
		await expect.element(page.getByLabelText('Rule 1 name')).toHaveValue('Thorns');
	});

	it('shows JSON preview when Show JSON is clicked', async () => {
		render(RuleBuilder, {
			gameConfig,
			rules: []
		});

		await expect.element(page.getByText('Compiled JSON')).not.toBeInTheDocument();

		await page.getByRole('button', { name: 'Show JSON' }).click();

		await expect.element(page.getByText('Compiled JSON')).toBeVisible();
	});

	it('hides JSON preview when Hide JSON is clicked', async () => {
		render(RuleBuilder, {
			gameConfig,
			rules: []
		});

		await page.getByRole('button', { name: 'Show JSON' }).click();
		await expect.element(page.getByText('Compiled JSON')).toBeVisible();

		await page.getByRole('button', { name: 'Hide JSON' }).click();
		await expect.element(page.getByText('Compiled JSON')).not.toBeInTheDocument();
	});

	it('shows JSON preview with rule data when rules are present', async () => {
		const rules: EcaRule[] = [
			{
				id: 'test-rule-1',
				name: 'Test Rule',
				trigger: 'on_after_mutate_property',
				conditions: [],
				actions: [{ MutateProperty: { target_id: 'self', property: 'hp', delta: 1 } }],
				cancels: false
			}
		];

		render(RuleBuilder, {
			gameConfig,
			rules
		});

		await page.getByRole('button', { name: 'Show JSON' }).click();

		await expect.element(page.getByText('"id"')).toBeVisible();
		await expect.element(page.getByText('"test-rule-1"')).toBeVisible();
		await expect.element(page.getByText('"on_after_mutate_property"')).toBeVisible();
	});

	it('shows copy error when clipboard write fails', async () => {
		render(RuleBuilder, {
			gameConfig,
			rules: []
		});

		await page.getByRole('button', { name: 'Show JSON' }).click();

		await expect.element(page.getByRole('button', { name: 'Copy' })).toBeVisible();
	});

	it('shows error badge when rule is invalid', async () => {
		const rules: EcaRule[] = [
			{
				id: 'bad-rule',
				name: 'Bad Rule',
				trigger: '',
				conditions: [],
				actions: [],
				cancels: false
			}
		];

		render(RuleBuilder, {
			gameConfig,
			rules
		});

		await expect.element(page.getByText(/invalid/)).toBeVisible();
	});

	it('shows error badge with correct count for multiple invalid rules', async () => {
		const rules: EcaRule[] = [
			{ id: 'bad-1', name: 'Bad 1', trigger: '', conditions: [], actions: [], cancels: false },
			{
				id: 'bad-2',
				name: 'Bad 2',
				trigger: 'invalid',
				conditions: [],
				actions: [],
				cancels: false
			}
		];

		render(RuleBuilder, {
			gameConfig,
			rules
		});

		await expect.element(page.getByText('2 invalid')).toBeVisible();
	});

	it('shows no error badge for valid rules', async () => {
		const rules: EcaRule[] = [
			{
				id: 'good-rule',
				name: 'Good Rule',
				trigger: 'on_after_mutate_property',
				conditions: [{ target: 'self', property: 'hp', operator: '==', value: 0 }],
				actions: [{ MutateProperty: { target_id: 'self', property: 'hp', delta: 1 } }],
				cancels: false
			}
		];

		render(RuleBuilder, {
			gameConfig,
			rules
		});

		await expect.element(page.getByText(/invalid/)).not.toBeInTheDocument();
	});
});
