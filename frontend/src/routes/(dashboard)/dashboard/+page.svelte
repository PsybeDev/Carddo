<script lang="ts">
	import { authStore } from '$lib/stores/auth';
</script>

<svelte:head><title>Dashboard — Carddo</title></svelte:head>

<div class="py-20 text-center">
	<h1 class="mb-2 text-2xl font-semibold text-slate-100">
		{#if authStore.currentUser}
			Welcome, {authStore.currentUser.email}
		{:else}
			Dashboard
		{/if}
	</h1>
	<p class="text-sm text-slate-400">Your games will appear here.</p>
</div>
