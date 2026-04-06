<script lang="ts">
	import type { Zone, Entity } from '$lib/types/ditto.generated';
	import CardBack from './CardBack.svelte';

	let { zone, entities, currentPlayerId, validDropTargets, onDrop }: {
		zone: Zone;
		entities: Record<string, Entity>;
		currentPlayerId: string;
		validDropTargets: string[];
		onDrop: (entityId: string, toZone: string) => void;
	} = $props();

	const isDropTarget = $derived(validDropTargets.includes(zone.id));
	const resolvedEntities = $derived(
		zone.entities.filter((id) => id in entities).map((id) => entities[id])
	);
	const isOwner = $derived(zone.owner_id === currentPlayerId);
	const visibility = $derived(zone.visibility);
	const hiddenCount = $derived(
		typeof visibility === 'object' && 'Hidden' in visibility ? visibility.Hidden : 0
	);
	const isHidden = $derived(typeof visibility === 'object' && 'Hidden' in visibility);
	const isOwnerOnly = $derived(visibility === 'OwnerOnly');
	const showEntities = $derived(visibility === 'Public' || (isOwnerOnly && isOwner));
	const showCardBacks = $derived(isOwnerOnly && !isOwner);
</script>

<div
	role="region"
	data-testid="zone-{zone.id}"
	class="rounded-lg border border-slate-700/50 bg-slate-800/40 p-3 min-h-[100px] {isDropTarget
		? 'ring-2 ring-indigo-500/70 bg-indigo-500/10'
		: ''}"
	ondragover={(e) => {
		if (isDropTarget) e.preventDefault();
	}}
	ondrop={(e) => {
		const entityId = e.dataTransfer?.getData('text/entity-id');
		if (entityId) onDrop(entityId, zone.id);
	}}
>
	<p class="text-xs text-slate-500 uppercase tracking-wide mb-2">{zone.id}</p>

	{#if isHidden}
		{#each { length: Math.min(hiddenCount, 5) } as _, i}
			<CardBack />
		{/each}
		{#if hiddenCount > 5}
			<span class="text-xs text-slate-400">+{hiddenCount - 5}</span>
		{/if}
	{:else if showEntities}
		{#each resolvedEntities as entity (entity.id)}
			<div
				role="button"
				tabindex="0"
				data-testid="entity-{entity.id}"
				class="bg-slate-700 rounded border border-slate-600 p-2 mb-1 cursor-grab active:cursor-grabbing"
				draggable="true"
				ondragstart={(e) => {
					e.dataTransfer?.setData('text/entity-id', entity.id);
				}}
			>
				<p class="text-xs text-slate-300 font-mono">{entity.template_id}</p>
				{#each Object.entries(entity.properties) as [key, value]}
					<span class="text-xs text-slate-500 mr-1">{key}: {value}</span>
				{/each}
			</div>
		{/each}
	{:else if showCardBacks}
		{#each resolvedEntities as entity (entity.id)}
			<CardBack />
		{/each}
	{/if}
</div>