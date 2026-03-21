<script lang="ts">
	import { goto } from '$app/navigation';
	import { ApiError, apiGet, apiPost } from '$lib/api/client';
	import type { Game } from '$lib/types/api';

	let games = $state<Game[]>([]);
	let loading = $state(true);
	let showModal = $state(false);
	let newTitle = $state('');
	let newDescription = $state('');
	let creating = $state(false);
	let createErrors = $state<string[]>([]);

	$effect(() => {
		void loadGames();
	});

	async function loadGames() {
		loading = true;
		try {
			games = await apiGet<Game[]>('/api/games');
		} catch {
			// show empty state on error
		} finally {
			loading = false;
		}
	}

	async function handleCreate(e: SubmitEvent) {
		e.preventDefault();
		createErrors = [];
		if (!newTitle.trim()) {
			createErrors = ['Title is required.'];
			return;
		}
		creating = true;
		try {
			const desc = newDescription.trim() || undefined;
			const game = await apiPost<Game>('/api/games', { title: newTitle.trim(), description: desc });
			games = [game, ...games];
			closeModal();
		} catch (err) {
			createErrors =
				err instanceof ApiError ? err.messages : ['Failed to create game. Please try again.'];
		} finally {
			creating = false;
		}
	}

	function openModal() {
		newTitle = '';
		newDescription = '';
		createErrors = [];
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		newTitle = '';
		newDescription = '';
		createErrors = [];
	}

	function formatDate(iso: string) {
		return new Date(iso).toLocaleDateString('en-US', {
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		});
	}
</script>

<svelte:head><title>Dashboard — Carddo</title></svelte:head>

<div class="flex items-center justify-between">
	<h1 class="text-lg font-semibold text-slate-100">Your Games</h1>
	<button
		type="button"
		onclick={openModal}
		class="flex items-center gap-1.5 rounded-lg bg-indigo-600 px-3.5 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none active:bg-indigo-700"
	>
		<svg
			xmlns="http://www.w3.org/2000/svg"
			class="h-4 w-4"
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			stroke-width="2"
			aria-hidden="true"
		>
			<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
		</svg>
		New Game
	</button>
</div>

<div class="mt-6">
	{#if loading}
		<div class="flex justify-center py-20">
			<svg
				class="h-6 w-6 animate-spin text-slate-500"
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
		</div>
	{:else if games.length === 0}
		<div class="flex flex-col items-center justify-center py-24 text-center">
			<div
				class="mb-4 flex h-14 w-14 items-center justify-center rounded-xl bg-indigo-600/10 ring-1 ring-indigo-500/20"
			>
				<svg
					xmlns="http://www.w3.org/2000/svg"
					class="h-7 w-7 text-indigo-400"
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
					stroke-width="1.5"
					aria-hidden="true"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875s-2.25.84-2.25 1.875c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 01-.657.643 48.39 48.39 0 01-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 01-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 00-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 01-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 00.657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 01-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 005.427-.63 48.05 48.05 0 00.582-4.717.532.532 0 00-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.4.959.4v0a.656.656 0 00.658-.663 48.422 48.422 0 00-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 01-.61-.58v0z"
					/>
				</svg>
			</div>
			<h2 class="text-base font-medium text-slate-200">No games yet</h2>
			<p class="mt-1 max-w-xs text-sm text-slate-400">
				Create your first game project to start building cards, decks, and rules.
			</p>
			<button
				type="button"
				onclick={openModal}
				class="mt-5 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
			>
				Create your first game
			</button>
		</div>
	{:else}
		<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
			{#each games as game (game.id)}
				<button
					type="button"
					onclick={() => goto(`/dashboard/games/${game.id}`)}
					class="group rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5 text-left transition hover:border-indigo-500/40 hover:bg-[#1e2133] focus:ring-2 focus:ring-indigo-500/40 focus:outline-none"
				>
					<div class="flex items-start justify-between gap-2">
						<h2
							class="truncate text-sm font-medium text-slate-100 transition group-hover:text-indigo-300"
						>
							{game.title}
						</h2>
						<svg
							xmlns="http://www.w3.org/2000/svg"
							class="mt-0.5 h-4 w-4 shrink-0 text-slate-600 transition group-hover:text-indigo-400"
							fill="none"
							viewBox="0 0 24 24"
							stroke="currentColor"
							stroke-width="2"
							aria-hidden="true"
						>
							<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
						</svg>
					</div>
					<p class="mt-2 text-xs text-slate-500">
						{game.card_count}
						{game.card_count === 1 ? 'card' : 'cards'} · Last edited {formatDate(game.updated_at)}
					</p>
				</button>
			{/each}
		</div>
	{/if}
</div>

<!-- Create Game Modal -->
{#if showModal}
	<div class="fixed inset-0 z-40 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm">
		<div class="fixed inset-0" aria-hidden="true" onclick={closeModal}></div>
		<div
			role="dialog"
			aria-modal="true"
			aria-labelledby="modal-title"
			class="relative w-full max-w-md rounded-xl border border-slate-700/50 bg-[#1a1d27] p-6 shadow-2xl shadow-black/60"
		>
			<div class="mb-5 flex items-center justify-between">
				<h2 id="modal-title" class="text-base font-semibold text-slate-100">Create New Game</h2>
				<button
					type="button"
					onclick={closeModal}
					class="rounded-md p-1 text-slate-500 transition hover:bg-slate-700/60 hover:text-slate-300"
					aria-label="Close"
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						class="h-5 w-5"
						fill="none"
						viewBox="0 0 24 24"
						stroke="currentColor"
						stroke-width="2"
						aria-hidden="true"
					>
						<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>

			{#if createErrors.length > 0}
				<div class="mb-4 rounded-lg border border-red-500/30 bg-red-500/10 p-3">
					{#each createErrors as msg (msg)}
						<p class="text-sm text-red-400">{msg}</p>
					{/each}
				</div>
			{/if}

			<form onsubmit={handleCreate}>
				<div class="mb-5">
					<label for="new-game-title" class="mb-1.5 block text-sm font-medium text-slate-300">
						Game title
					</label>
					<!-- svelte-ignore a11y_autofocus -->
					<input
						id="new-game-title"
						type="text"
						bind:value={newTitle}
						placeholder="e.g. Dungeon Siege, Star Clash…"
						maxlength="80"
						autofocus
						class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 disabled:opacity-50"
						disabled={creating}
					/>
				</div>

				<div class="mb-5">
					<label for="new-game-description" class="mb-1.5 block text-sm font-medium text-slate-300">
						Description <span class="text-slate-500">(optional)</span>
					</label>
					<textarea
						id="new-game-description"
						bind:value={newDescription}
						placeholder="A short description of your game…"
						maxlength="500"
						rows="3"
						class="w-full resize-none rounded-lg border border-slate-600 bg-slate-800/60 px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 disabled:opacity-50"
						disabled={creating}
					></textarea>
				</div>

				<div class="flex gap-3">
					<button
						type="button"
						onclick={closeModal}
						disabled={creating}
						class="flex-1 rounded-lg border border-slate-600 px-4 py-2.5 text-sm font-medium text-slate-300 transition hover:bg-slate-700/60 disabled:opacity-50"
					>
						Cancel
					</button>
					<button
						type="submit"
						disabled={creating}
						class="flex flex-1 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-500 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none active:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-60"
					>
						{#if creating}
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
				</div>
			</form>
		</div>
	</div>
{/if}
