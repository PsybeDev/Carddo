<script lang="ts">
	let { visible, winnerId }: { visible: boolean; winnerId?: string } = $props();
</script>

{#if visible}
	<div
		data-testid="winner-screen"
		class="pointer-events-auto absolute inset-0 z-50 flex items-center justify-center bg-black/70"
	>
		<div class="text-center">
			<h2 class="text-3xl font-bold text-white">Game Over</h2>
			{#if winnerId}
				<p class="mt-2 text-lg text-slate-300">Winner: {winnerId}</p>
			{/if}
		</div>
	</div>
{/if}
