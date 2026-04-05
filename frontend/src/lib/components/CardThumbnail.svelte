<script lang="ts">
	import type { Card } from '$lib/types/api';

	let { card }: { card: Card } = $props();

	let bg = $derived(card.background_color ?? '#1e2235');
	let propertyEntries = $derived(Object.entries(card.properties));
</script>

<div
	class="relative flex aspect-[2/3] w-full flex-col overflow-hidden rounded-xl border border-white/10 shadow-md"
	style:background-color={bg}
>
	<!-- Property chips -->
	{#if propertyEntries.length > 0}
		<div class="flex flex-wrap gap-1 p-2">
			{#each propertyEntries as [key, val] (key)}
				<span
					class="rounded-full bg-black/40 px-2 py-0.5 text-[10px] font-medium text-white/90 backdrop-blur-sm"
				>
					{key}: {val}
				</span>
			{/each}
		</div>
	{/if}

	<!-- Card name footer -->
	<div class="mt-auto bg-black/50 px-3 py-2 backdrop-blur-sm">
		<p class="truncate text-sm font-semibold text-white">{card.name}</p>
		<p class="truncate text-[10px] text-white/60">{card.card_type}</p>
	</div>
</div>
