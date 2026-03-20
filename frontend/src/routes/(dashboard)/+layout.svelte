<script lang="ts">
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth.svelte';
	import { toastStore } from '$lib/stores/toast.svelte';

	let { children } = $props();

	function handleLogout() {
		authStore.logout();
		goto('/login');
	}
</script>

<div class="min-h-screen bg-[#0f1117]">
	<header class="border-b border-slate-700/50 bg-[#1a1d27]">
		<div class="mx-auto flex h-14 max-w-7xl items-center justify-between px-4 sm:px-6">
			<div class="flex items-center gap-2">
				<svg
					width="22"
					height="22"
					viewBox="0 0 28 28"
					fill="none"
					xmlns="http://www.w3.org/2000/svg"
					aria-hidden="true"
				>
					<rect width="28" height="28" rx="6" fill="url(#dash-grad)" />
					<path d="M7 14L14 7L21 14L14 21L7 14Z" fill="white" opacity="0.9" />
					<defs>
						<linearGradient id="dash-grad" x1="0" y1="0" x2="28" y2="28">
							<stop offset="0%" stop-color="#6366f1" />
							<stop offset="100%" stop-color="#8b5cf6" />
						</linearGradient>
					</defs>
				</svg>
				<span class="text-sm font-semibold tracking-tight text-slate-100">Carddo</span>
			</div>

			<button
				type="button"
				onclick={handleLogout}
				class="rounded-md px-3 py-1.5 text-xs font-medium text-slate-400 transition hover:bg-slate-700/60 hover:text-slate-200"
			>
				Log out
			</button>
		</div>
	</header>

	<main class="mx-auto max-w-7xl px-4 py-8 sm:px-6">
		{@render children()}
	</main>
</div>

<!-- Toast notifications -->
<div class="pointer-events-none fixed right-6 bottom-6 z-50 flex flex-col gap-2">
	{#each toastStore.list as toast (toast.id)}
		<div
			class="pointer-events-auto flex items-center gap-3 rounded-lg border px-4 py-3 text-sm shadow-lg shadow-black/40
				{toast.type === 'error'
				? 'border-red-500/30 bg-red-950/90 text-red-300'
				: toast.type === 'success'
					? 'border-emerald-500/30 bg-emerald-950/90 text-emerald-300'
					: 'border-slate-600/50 bg-[#1a1d27] text-slate-300'}"
		>
			{toast.message}
		</div>
	{/each}
</div>
