<script lang="ts">
	let {
		trigger = $bindable(),
		ruleIndex
	}: {
		trigger: string;
		ruleIndex: number;
	} = $props();

	function parseTrigger(t: string) {
		const selfOnly = t.endsWith(':self');
		const base = selfOnly ? t.slice(0, -5) : t;
		const phase = base.startsWith('on_before_') ? 'on_before_' : 'on_after_';
		const actionType = base.slice(phase.length) || 'any';
		return { phase, actionType, selfOnly };
	}

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
		trigger = `${phase}${actionType}${selfOnly ? ':self' : ''}`;
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
		<option value="on_before_">Before</option>
		<option value="on_after_">After</option>
	</select>

	<select
		bind:value={actionType}
		onchange={updateTrigger}
		aria-label={`Rule ${ruleIndex + 1} trigger action`}
		class="w-48 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
	>
		<option value="mutate_property">Mutate Property</option>
		<option value="move_entity">Move Entity</option>
		<option value="spawn_entity">Spawn Entity</option>
		<option value="end_turn">End Turn</option>
		<option value="any">Any Action</option>
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
