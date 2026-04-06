<script lang="ts">
	let { count }: { count?: number } = $props();
</script>

<div
	data-testid="card-back"
	aria-label="Hidden card"
	class="relative w-20 h-28 bg-slate-900 border border-slate-700 rounded-lg flex items-center justify-center"
>
	<span class="text-xs text-slate-600 select-none">Carddo</span>
	{#if count !== undefined && count > 1}
		<span
			class="absolute top-1 right-1 text-xs bg-slate-700 text-slate-300 rounded-full px-1.5 py-0.5 min-w-[1.25rem] text-center"
		>
			{count}
		</span>
	{/if}
</div>
