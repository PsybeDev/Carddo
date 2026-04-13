<script lang="ts">
	let {
		visible,
		winnerId,
		onReturnToDashboard
	}: { visible: boolean; winnerId?: string; onReturnToDashboard?: () => void } = $props();
</script>

{#if visible}
	<div
		role="dialog"
		aria-modal="true"
		aria-labelledby="winner-screen-title"
		data-testid="winner-screen"
		class="pointer-events-auto absolute inset-0 z-50 flex items-center justify-center bg-black/70"
	>
		<div class="text-center">
			<h2 id="winner-screen-title" class="text-3xl font-bold text-white">Game Over</h2>
			{#if winnerId}
				<p class="mt-2 text-lg text-slate-300">Winner: {winnerId}</p>
			{/if}
			{#if onReturnToDashboard}
				<button
					type="button"
					onclick={onReturnToDashboard}
					class="mt-6 rounded-lg bg-indigo-600 px-6 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-500"
				>
					Return to Dashboard
				</button>
			{/if}
		</div>
	</div>
{/if}
