<script lang="ts">
	import type { EcaRule, GameConfig } from '$lib/types/api';
	import RuleBlock from './RuleBlock.svelte';
	import { createEmptyRule } from './utils';

	let {
		gameConfig,
		rules = $bindable(),
		onchange
	}: {
		gameConfig: GameConfig;
		rules: EcaRule[];
		onchange?: (rules: EcaRule[]) => void;
	} = $props();

	let ruleKeys = $state<number[]>(rules.map((_, i) => i));
	let _nextKey = rules.length;

	function addRule() {
		rules = [...rules, createEmptyRule()];
		ruleKeys = [...ruleKeys, ++_nextKey];
	}

	function removeRule(i: number) {
		rules = rules.filter((_, idx) => idx !== i);
		ruleKeys = ruleKeys.filter((_, idx) => idx !== i);
	}

	$effect(() => {
		onchange?.(rules);
	});
</script>

<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
	<div class="mb-4 flex items-center justify-between">
		<div>
			<h2 class="text-sm font-semibold text-slate-100">Engine Rules</h2>
			<p class="mt-0.5 text-xs text-slate-500">
				Define game mechanics using Event-Condition-Action (ECA) triggers.
			</p>
		</div>
		<button
			type="button"
			onclick={addRule}
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
			Add Rule
		</button>
	</div>

	{#if rules.length > 0}
		<div class="space-y-4">
			{#each rules as rule, i (ruleKeys[i])}
				<RuleBlock {rule} {gameConfig} ruleIndex={i} onremove={() => removeRule(i)} />
			{/each}
		</div>
	{:else}
		<p class="py-6 text-center text-sm text-slate-500">
			No rules yet. Add one to define game behavior.
		</p>
	{/if}
</div>
