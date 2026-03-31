<script lang="ts">
	import type { EcaCondition } from '$lib/types/api';
	import { CONDITION_OPERATORS } from './utils';

	let {
		condition = $bindable(),
		properties,
		conditionIndex,
		ruleIndex,
		onremove
	}: {
		condition: EcaCondition;
		properties: string[];
		conditionIndex: number;
		ruleIndex: number;
		onremove: () => void;
	} = $props();

	function handleValueInput(e: Event) {
		const raw = (e.currentTarget as HTMLInputElement).value;
		if (raw === '') {
			condition.value = 0;
			return;
		}
		const parsed = Number(raw);
		if (Number.isFinite(parsed)) {
			condition.value = parsed;
		}
	}
</script>

<div class="flex flex-wrap items-center gap-3">
	<span class="w-12 text-xs font-medium tracking-wide text-slate-500 uppercase">If</span>

	<div class="flex flex-1 items-center gap-2">
		<input
			type="text"
			bind:value={condition.target}
			placeholder="Entity ID (e.g. self)"
			aria-label={`Rule ${ruleIndex + 1} condition ${conditionIndex + 1} target`}
			class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
		/>

		<select
			bind:value={condition.property}
			aria-label={`Rule ${ruleIndex + 1} condition ${conditionIndex + 1} property`}
			class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
		>
			<option value="" disabled>Select property</option>
			{#each properties as prop (prop)}
				<option value={prop}>{prop}</option>
			{/each}
		</select>

		<select
			bind:value={condition.operator}
			aria-label={`Rule ${ruleIndex + 1} condition ${conditionIndex + 1} operator`}
			class="w-20 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
		>
			{#each CONDITION_OPERATORS as op (op.value)}
				<option value={op.value}>{op.label}</option>
			{/each}
		</select>

		<input
			type="number"
			value={condition.value}
			oninput={handleValueInput}
			placeholder="0"
			aria-label={`Rule ${ruleIndex + 1} condition ${conditionIndex + 1} value`}
			class="w-24 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
		/>
	</div>

	<button
		type="button"
		onclick={onremove}
		aria-label={`Remove rule ${ruleIndex + 1} condition ${conditionIndex + 1}`}
		class="flex h-9 w-9 items-center justify-center rounded-lg text-slate-500 transition hover:bg-red-500/10 hover:text-red-400"
	>
		<svg
			xmlns="http://www.w3.org/2000/svg"
			class="h-4 w-4"
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			stroke-width="2"
			aria-hidden="true"
		>
			<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
		</svg>
	</button>
</div>
