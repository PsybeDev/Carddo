<script lang="ts">
	import type { Zone, Entity } from '$lib/types/ditto.generated';
	import CardBack from './CardBack.svelte';
	import Card from './Card.svelte';

	let {
		zone,
		entities,
		currentPlayerId,
		validDropTargets,
		onDrop,
		disabled = false
	}: {
		zone: Zone;
		entities: Record<string, Entity>;
		currentPlayerId: string;
		validDropTargets: string[];
		onDrop: (entityId: string, toZone: string) => void;
		disabled?: boolean;
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
	aria-label={zone.id}
	data-testid="zone-{zone.id}"
	class="min-h-[100px] rounded-lg border border-slate-700/50 bg-slate-800/40 p-3 {isDropTarget &&
	!disabled
		? 'bg-indigo-500/10 ring-2 ring-indigo-500/70'
		: ''}"
	ondragover={(e) => {
		if (!disabled && isDropTarget) e.preventDefault();
	}}
	ondrop={(e) => {
		if (disabled || !isDropTarget) return;
		e.preventDefault();
		e.stopPropagation();
		const entityId = e.dataTransfer?.getData('text/entity-id');
		if (entityId) onDrop(entityId, zone.id);
	}}
>
	<p class="mb-2 text-xs tracking-wide text-slate-500 uppercase">{zone.id}</p>

	{#if isHidden}
		{#each { length: Math.min(hiddenCount, 5) } as _i, i (i)}
			<CardBack />
		{/each}
		{#if hiddenCount > 5}
			<span class="text-xs text-slate-400">+{hiddenCount - 5}</span>
		{/if}
	{:else if showEntities}
		{#each resolvedEntities as entity (entity.id)}
			<Card {entity} {isOwner} {disabled} {validDropTargets} onDropAttempt={onDrop} />
		{/each}
	{:else if showCardBacks}
		{#each resolvedEntities as entity (entity.id)}
			<CardBack />
		{/each}
	{/if}
</div>
