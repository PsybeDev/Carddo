<script lang="ts">
	import { goto } from '$app/navigation';
	import { ApiError, apiPost } from '$lib/api/client';

	let gameName = $state('');
	let loading = $state(false);
	let errors = $state<string[]>([]);

	async function handleCreate(e: SubmitEvent) {
		e.preventDefault();
		errors = [];
		if (!gameName.trim()) {
			errors = ['Give your game a name.'];
			return;
		}

		loading = true;
		try {
			await apiPost('/api/games', { name: gameName.trim() });
			goto('/dashboard');
		} catch (err) {
			errors = err instanceof ApiError ? err.messages : ['Failed to create game. Try again.'];
		} finally {
			loading = false;
		}
	}

	function handleSkip() {
		goto('/dashboard');
	}
</script>

<svelte:head><title>Welcome — Carddo</title></svelte:head>

<div class="flex min-h-[60vh] flex-col items-center justify-center">
	<div class="w-full max-w-md">
		<div class="mb-8 text-center">
			<div
				class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-600/20 ring-1 ring-indigo-500/30"
			>
				<svg
					xmlns="http://www.w3.org/2000/svg"
					class="h-6 w-6 text-indigo-400"
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
					stroke-width="1.5"
					aria-hidden="true"
				>
					<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
				</svg>
			</div>
			<h1 class="text-2xl font-semibold text-slate-100">Welcome to Carddo</h1>
			<p class="mt-2 text-sm text-slate-400">Create your first game to get started.</p>
		</div>

		<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-6 shadow-2xl shadow-black/40">
			{#if errors.length > 0}
				<div class="mb-4 rounded-lg border border-red-500/30 bg-red-500/10 p-3">
					{#each errors as msg (msg)}
						<p class="text-sm text-red-400">{msg}</p>
					{/each}
				</div>
			{/if}

			<form onsubmit={handleCreate}>
				<div class="mb-5">
					<label for="game-name" class="mb-1.5 block text-sm font-medium text-slate-300"
						>Game name</label
					>
					<input
						id="game-name"
						type="text"
						bind:value={gameName}
						placeholder="e.g. Dungeon Siege, Star Clash…"
						maxlength="80"
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
							<circle
								class="opacity-25"
								cx="12"
								cy="12"
								r="10"
								stroke="currentColor"
								stroke-width="4"
							></circle>
							<path
								class="opacity-75"
								fill="currentColor"
								d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
							></path>
						</svg>
						Creating…
					{:else}
						Create Game
					{/if}
				</button>
			</form>

			<div class="mt-4 text-center">
				<button
					type="button"
					onclick={handleSkip}
					class="text-sm text-slate-500 transition hover:text-slate-400"
				>
					Skip for now →
				</button>
			</div>
		</div>
	</div>
</div>
