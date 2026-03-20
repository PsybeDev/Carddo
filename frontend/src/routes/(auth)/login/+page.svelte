<script lang="ts">
	import { goto } from '$app/navigation';
	import { ApiError } from '$lib/api/client';
	import { authStore } from '$lib/stores/auth';

	let email = $state('');
	let password = $state('');
	let errors = $state<string[]>([]);
	let loading = $state(false);

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		errors = [];

		if (!email.trim() || !password.trim()) {
			errors = ['Email and password are required.'];
			return;
		}

		loading = true;
		try {
			await authStore.login(email, password);
			goto('/dashboard');
		} catch (err) {
			errors = err instanceof ApiError ? err.messages : ['Something went wrong. Try again.'];
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Sign In — Carddo</title></svelte:head>

<h1 class="mb-1 text-xl font-semibold text-slate-100">Welcome back</h1>
<p class="mb-6 text-sm text-slate-400">Sign in to your Carddo account</p>

{#if errors.length > 0}
	<div class="mb-5 rounded-lg border border-red-500/30 bg-red-500/10 p-3">
		{#each errors as msg (msg)}
			<p class="text-sm text-red-400">{msg}</p>
		{/each}
	</div>
{/if}

<form onsubmit={handleSubmit} novalidate>
	<div class="mb-4">
		<label for="email" class="mb-1.5 block text-sm font-medium text-slate-300">Email</label>
		<input
			id="email"
			type="email"
			bind:value={email}
			autocomplete="email"
			placeholder="you@example.com"
			class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 disabled:opacity-50"
			disabled={loading}
		/>
	</div>

	<div class="mb-6">
		<label for="password" class="mb-1.5 block text-sm font-medium text-slate-300">Password</label>
		<input
			id="password"
			type="password"
			bind:value={password}
			autocomplete="current-password"
			placeholder="••••••••"
			class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 disabled:opacity-50"
			disabled={loading}
		/>
	</div>

	<button
		type="submit"
		disabled={loading}
		class="flex w-full items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-500 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none active:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-60"
	>
		{#if loading}
			<svg
				class="h-4 w-4 animate-spin"
				xmlns="http://www.w3.org/2000/svg"
				fill="none"
				viewBox="0 0 24 24"
				aria-hidden="true"
			>
				<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"
				></circle>
				<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
				></path>
			</svg>
			Signing in…
		{:else}
			Sign In
		{/if}
	</button>
</form>

<p class="mt-5 text-center text-sm text-slate-500">
	Don't have an account?
	<a href="/register" class="font-medium text-indigo-400 hover:text-indigo-300">Register</a>
</p>
