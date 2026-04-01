<script lang="ts">
	import type { EcaAction } from '$lib/types/api';
	import { parseI32, parseUsize } from './utils';

	let {
		action = $bindable(),
		properties,
		zones,
		actionIndex,
		ruleIndex,
		onremove
	}: {
		action: EcaAction;
		properties: string[];
		zones: string[];
		actionIndex: number;
		ruleIndex: number;
		onremove: () => void;
	} = $props();

	let actionType = $derived(
		action === 'EndTurn'
			? 'EndTurn'
			: typeof action === 'object' && action !== null
				? 'MutateProperty' in action
					? 'MutateProperty'
					: 'MoveEntity' in action
						? 'MoveEntity'
						: 'SpawnEntity' in action
							? 'SpawnEntity'
							: 'EndTurn'
				: 'EndTurn'
	);

	function handleTypeChange(e: Event) {
		const newType = (e.currentTarget as HTMLSelectElement).value;
		if (newType === 'EndTurn') {
			action = 'EndTurn';
		} else if (newType === 'MutateProperty') {
			action = { MutateProperty: { target_id: '', property: '', delta: 0 } };
		} else if (newType === 'MoveEntity') {
			action = { MoveEntity: { entity_id: '', from_zone: '', to_zone: '', index: null } };
		} else if (newType === 'SpawnEntity') {
			action = { SpawnEntity: { entity: {}, zone_id: '' } };
		}
	}

	function handleDeltaInput(e: Event) {
		if (typeof action !== 'object' || !('MutateProperty' in action)) return;
		const raw = (e.currentTarget as HTMLInputElement).value;
		action.MutateProperty.delta = parseI32(raw) ?? 0;
	}

	function handleIndexInput(e: Event) {
		if (typeof action !== 'object' || !('MoveEntity' in action)) return;
		const raw = (e.currentTarget as HTMLInputElement).value;
		action.MoveEntity.index = raw === '' ? null : (parseUsize(raw) ?? null);
	}
</script>

<div class="flex flex-wrap items-center gap-3">
	<span class="w-12 text-xs font-medium tracking-wide text-slate-500 uppercase">Then</span>

	<div class="flex flex-1 items-center gap-2">
		<select
			value={actionType}
			onchange={handleTypeChange}
			aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} type`}
			class="w-40 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
		>
			<option value="MutateProperty">Mutate Property</option>
			<option value="MoveEntity">Move Entity</option>
			<option value="SpawnEntity">Spawn Entity</option>
			<option value="EndTurn">End Turn</option>
		</select>

		{#if typeof action === 'object' && action !== null}
			{#if 'MutateProperty' in action}
				<input
					type="text"
					bind:value={action.MutateProperty.target_id}
					placeholder="Entity ID"
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} target`}
					class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				/>
				<select
					bind:value={action.MutateProperty.property}
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} property`}
					class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				>
					<option value="" disabled>Select property</option>
					{#each properties as prop (prop)}
						<option value={prop}>{prop}</option>
					{/each}
				</select>
				<input
					type="number"
					step="1"
					value={action.MutateProperty.delta}
					oninput={handleDeltaInput}
					placeholder="0"
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} delta`}
					class="w-24 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				/>
			{:else if 'MoveEntity' in action}
				<input
					type="text"
					bind:value={action.MoveEntity.entity_id}
					placeholder="Entity ID"
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} entity`}
					class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				/>
				<select
					bind:value={action.MoveEntity.from_zone}
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} from zone`}
					class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				>
					<option value="" disabled>From zone</option>
					{#each zones as zone (zone)}
						<option value={zone}>{zone}</option>
					{/each}
				</select>
				<select
					bind:value={action.MoveEntity.to_zone}
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} to zone`}
					class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				>
					<option value="" disabled>To zone</option>
					{#each zones as zone (zone)}
						<option value={zone}>{zone}</option>
					{/each}
				</select>
				<input
					type="number"
					step="1"
					min="0"
					value={action.MoveEntity.index ?? ''}
					oninput={handleIndexInput}
					placeholder="Idx"
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} index`}
					class="w-20 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				/>
			{:else if 'SpawnEntity' in action}
				<span class="text-sm text-slate-400">Entity setup is hidden...</span>
				<select
					bind:value={action.SpawnEntity.zone_id}
					aria-label={`Rule ${ruleIndex + 1} action ${actionIndex + 1} spawn zone`}
					class="w-32 flex-1 rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
				>
					<option value="" disabled>Select zone</option>
					{#each zones as zone (zone)}
						<option value={zone}>{zone}</option>
					{/each}
				</select>
			{/if}
		{/if}
	</div>

	<button
		type="button"
		onclick={onremove}
		aria-label={`Remove rule ${ruleIndex + 1} action ${actionIndex + 1}`}
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
