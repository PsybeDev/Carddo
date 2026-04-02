<script lang="ts">
	import type { EcaRule, GameConfig } from '$lib/types/api';
	import type { ValidationError } from '$lib/utils/schema-validator';
	import TriggerBlock from './TriggerBlock.svelte';
	import ConditionBlock from './ConditionBlock.svelte';
	import ActionBlock from './ActionBlock.svelte';

	let {
		rule = $bindable(),
		gameConfig,
		ruleIndex,
		errors = [],
		onremove
	}: {
		rule: EcaRule;
		gameConfig: GameConfig;
		ruleIndex: number;
		errors?: ValidationError[];
		onremove: () => void;
	} = $props();

	let hasErrors = $derived(errors.length > 0);

	let propertyNames = $derived(gameConfig.properties.map((p) => p.name));
	let zoneNames = $derived(gameConfig.zones.map((z) => z.name));

	let conditionKeys = $state<number[]>(rule.conditions.map((_, i) => i));
	let actionKeys = $state<number[]>(rule.actions.map((_, i) => i));
	let _nextKey = Math.max(rule.conditions.length, rule.actions.length);

	function addCondition() {
		rule.conditions = [...rule.conditions, { target: '', property: '', operator: '==', value: 0 }];
		conditionKeys = [...conditionKeys, ++_nextKey];
	}

	function removeCondition(i: number) {
		rule.conditions = rule.conditions.filter((_, idx) => idx !== i);
		conditionKeys = conditionKeys.filter((_, idx) => idx !== i);
	}

	function addAction() {
		rule.actions = [...rule.actions, { MutateProperty: { target_id: '', property: '', delta: 0 } }];
		actionKeys = [...actionKeys, ++_nextKey];
	}

	function removeAction(i: number) {
		rule.actions = rule.actions.filter((_, idx) => idx !== i);
		actionKeys = actionKeys.filter((_, idx) => idx !== i);
	}
</script>

<div class="space-y-4 rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
	<div class="space-y-2">
		<div class="flex items-center justify-between gap-3">
			<input
				type="text"
				bind:value={rule.name}
				placeholder="e.g. Thorns, Divine Shield"
				aria-label={`Rule ${ruleIndex + 1} name`}
				class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm font-medium text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
			/>
			{#if hasErrors}
				{@const tooltipId = `rule-${ruleIndex}-errors`}
				<div class="group relative flex-shrink-0">
					<span
						class="flex h-6 w-6 items-center justify-center rounded-full bg-red-500/20 text-red-400"
						role="img"
						aria-label={`${errors.length} validation error${errors.length > 1 ? 's' : ''}`}
						aria-describedby={tooltipId}
					>
						<svg
							xmlns="http://www.w3.org/2000/svg"
							class="h-4 w-4"
							viewBox="0 0 20 20"
							fill="currentColor"
							aria-hidden="true"
						>
							<path
								fill-rule="evenodd"
								d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
								clip-rule="evenodd"
							/>
						</svg>
					</span>
					<div
						id={tooltipId}
						class="absolute top-full right-0 z-10 mt-1 hidden w-64 rounded-lg border border-red-900/50 bg-red-950/95 p-2 text-xs text-red-300 shadow-lg group-focus-within:block group-hover:block"
					>
						<ul class="space-y-1">
							{#each errors as error (error.field)}
								<li class="flex gap-1">
									<span class="font-mono text-red-400">{error.field}</span>
									<span class="text-red-500/70">{error.message}</span>
								</li>
							{/each}
						</ul>
					</div>
				</div>
			{/if}
		</div>
	</div>

	<div class="flex items-center gap-4">
		<TriggerBlock bind:trigger={rule.trigger} {ruleIndex} />
		<label class="flex items-center gap-2 text-sm text-slate-300">
			<input
				type="checkbox"
				bind:checked={rule.cancels}
				class="rounded border-slate-600 bg-slate-800 text-indigo-500 focus:ring-indigo-500/50 focus:ring-offset-0"
			/>
			Cancels triggering event
			<span class="text-xs text-slate-500">(only applies to Before-phase triggers)</span>
		</label>
	</div>

	<div class="space-y-2">
		{#each rule.conditions as _cond, i (conditionKeys[i])}
			<ConditionBlock
				bind:condition={rule.conditions[i]}
				properties={propertyNames}
				conditionIndex={i}
				{ruleIndex}
				onremove={() => removeCondition(i)}
			/>
		{/each}
		<button
			type="button"
			onclick={addCondition}
			class="flex items-center gap-1.5 rounded-lg border border-slate-600/60 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-indigo-500/50 hover:bg-indigo-600/10 hover:text-indigo-300"
		>
			<svg
				xmlns="http://www.w3.org/2000/svg"
				class="h-3.5 w-3.5"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
				aria-hidden="true"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
			</svg>
			Add Condition
		</button>
	</div>

	<div class="space-y-2">
		{#each rule.actions as _action, i (actionKeys[i])}
			<ActionBlock
				bind:action={rule.actions[i]}
				properties={propertyNames}
				zones={zoneNames}
				actionIndex={i}
				{ruleIndex}
				onremove={() => removeAction(i)}
			/>
		{/each}
		<button
			type="button"
			onclick={addAction}
			class="flex items-center gap-1.5 rounded-lg border border-slate-600/60 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-indigo-500/50 hover:bg-indigo-600/10 hover:text-indigo-300"
		>
			<svg
				xmlns="http://www.w3.org/2000/svg"
				class="h-3.5 w-3.5"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
				aria-hidden="true"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
			</svg>
			Add Action
		</button>
	</div>

	<div class="flex justify-end pt-2">
		<button
			type="button"
			onclick={onremove}
			class="flex items-center gap-1.5 rounded-lg border border-red-900/50 px-3 py-1.5 text-xs font-medium text-red-400 transition hover:bg-red-500/10 hover:text-red-300"
		>
			<svg
				xmlns="http://www.w3.org/2000/svg"
				class="h-3.5 w-3.5"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
				aria-hidden="true"
			>
				<path
					stroke-linecap="round"
					stroke-linejoin="round"
					d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
				/>
			</svg>
			Delete Rule
		</button>
	</div>
</div>
