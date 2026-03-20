<script lang="ts">
	import { goto } from '$app/navigation';
	import { ApiError } from '$lib/api/client';
	import { authStore } from '$lib/stores/auth.svelte';

	let email = $state('');
	let password = $state('');
	let confirm = $state('');
	let loading = $state(false);
	let apiErrors = $state<string[]>([]);

	let touched = $state({ email: false, password: false, confirm: false });

	let emailError = $derived(
		touched.email && !email.includes('@') ? 'Enter a valid email address.' : null
	);
	let passwordError = $derived(
		touched.password && password.length < 8 ? 'Password must be at least 8 characters.' : null
	);
	let confirmError = $derived(
		touched.confirm && confirm !== password ? 'Passwords do not match.' : null
	);

	let formValid = $derived(email.includes('@') && password.length >= 8 && confirm === password);

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		touched = { email: true, password: true, confirm: true };
		apiErrors = [];
		if (!formValid) return;

		loading = true;
		try {
			await authStore.register(email, password);
			goto('/dashboard/onboarding');
		} catch (err) {
			apiErrors = err instanceof ApiError ? err.messages : ['Something went wrong. Try again.'];
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Account — Carddo</title></svelte:head>

<h1 class="mb-1 text-xl font-semibold text-slate-100">Create your account</h1>
<p class="mb-6 text-sm text-slate-400">Start building card games today</p>

{#if apiErrors.length > 0}
	<div class="mb-5 rounded-lg border border-red-500/30 bg-red-500/10 p-3">
		{#each apiErrors as msg (msg)}
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
			onblur={() => (touched.email = true)}
			autocomplete="email"
			placeholder="you@example.com"
			class="w-full rounded-lg border px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:ring-1 disabled:opacity-50
				{emailError
				? 'border-red-500/60 bg-red-500/5 focus:border-red-500 focus:ring-red-500/30'
				: 'border-slate-600 bg-slate-800/60 focus:border-indigo-500 focus:ring-indigo-500/50'}"
			disabled={loading}
		/>
		{#if emailError}
			<p class="mt-1 text-xs text-red-400">{emailError}</p>
		{/if}
	</div>

	<div class="mb-4">
		<label for="password" class="mb-1.5 block text-sm font-medium text-slate-300">Password</label>
		<input
			id="password"
			type="password"
			bind:value={password}
			onblur={() => (touched.password = true)}
			autocomplete="new-password"
			placeholder="Min. 8 characters"
			class="w-full rounded-lg border px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:ring-1 disabled:opacity-50
				{passwordError
				? 'border-red-500/60 bg-red-500/5 focus:border-red-500 focus:ring-red-500/30'
				: 'border-slate-600 bg-slate-800/60 focus:border-indigo-500 focus:ring-indigo-500/50'}"
			disabled={loading}
		/>
		{#if passwordError}
			<p class="mt-1 text-xs text-red-400">{passwordError}</p>
		{/if}
	</div>

	<div class="mb-6">
		<label for="confirm" class="mb-1.5 block text-sm font-medium text-slate-300"
			>Confirm password</label
		>
		<input
			id="confirm"
			type="password"
			bind:value={confirm}
			onblur={() => (touched.confirm = true)}
			autocomplete="new-password"
			placeholder="••••••••"
			class="w-full rounded-lg border px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:ring-1 disabled:opacity-50
				{confirmError
				? 'border-red-500/60 bg-red-500/5 focus:border-red-500 focus:ring-red-500/30'
				: 'border-slate-600 bg-slate-800/60 focus:border-indigo-500 focus:ring-indigo-500/50'}"
			disabled={loading}
		/>
		{#if confirmError}
			<p class="mt-1 text-xs text-red-400">{confirmError}</p>
		{/if}
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
			Creating account…
		{:else}
			Create Account
		{/if}
	</button>
</form>

<p class="mt-5 text-center text-sm text-slate-500">
	Already have an account?
	<a href="/login" class="font-medium text-indigo-400 hover:text-indigo-300">Sign In</a>
</p>
