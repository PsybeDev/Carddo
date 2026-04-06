<script lang="ts">
	let { count }: { count?: number } = $props();
</script>

<div
	role="img"
	data-testid="card-back"
	aria-label="Hidden card"
	class="relative flex h-28 w-20 items-center justify-center rounded-lg border border-slate-700 bg-slate-900"
>
	<span aria-hidden="true" class="text-xs text-slate-600 select-none">Carddo</span>
	{#if count !== undefined && count > 1}
		<span
			class="absolute top-1 right-1 min-w-[1.25rem] rounded-full bg-slate-700 px-1.5 py-0.5 text-center text-xs text-slate-300"
		>
			{count}
		</span>
	{/if}
</div>
