<script lang="ts">
	import { parseTrigger, composeTrigger, TRIGGER_PHASES, TRIGGER_ACTION_TYPES } from './utils';

	let {
		trigger = $bindable(),
		ruleIndex
	}: {
		trigger: string;
		ruleIndex: number;
	} = $props();

	let initial = parseTrigger(trigger);
	let phase = $state(initial.phase);
	let actionType = $state(initial.actionType);
	let selfOnly = $state(initial.selfOnly);

	$effect(() => {
		const p = parseTrigger(trigger);
		phase = p.phase;
		actionType = p.actionType;
		selfOnly = p.selfOnly;
	});

	function updateTrigger() {
		trigger = composeTrigger(phase, actionType, selfOnly);
	}
</script>

<div class="flex items-center gap-3">
	<span class="w-12 text-xs font-medium tracking-wide text-slate-500 uppercase">When</span>

	<select
		bind:value={phase}
		onchange={updateTrigger}
		aria-label={`Rule ${ruleIndex + 1} trigger phase`}
		class="w-32 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
	>
		{#each TRIGGER_PHASES as p (p.value)}
			<option value={p.value}>{p.label}</option>
		{/each}
	</select>

	<select
		bind:value={actionType}
		onchange={updateTrigger}
		aria-label={`Rule ${ruleIndex + 1} trigger action`}
		class="w-48 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
	>
		{#each TRIGGER_ACTION_TYPES as a (a.value)}
			<option value={a.value}>{a.label}</option>
		{/each}
	</select>

	<label class="ml-2 flex items-center gap-2 text-sm text-slate-300">
		<input
			type="checkbox"
			bind:checked={selfOnly}
			onchange={updateTrigger}
			class="rounded border-slate-600 bg-slate-800 text-indigo-500 focus:ring-indigo-500/50 focus:ring-offset-0"
		/>
		Self only
	</label>
</div>
