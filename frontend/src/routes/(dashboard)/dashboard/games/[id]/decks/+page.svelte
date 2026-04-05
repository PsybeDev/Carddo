<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { ApiError, apiDelete, apiPost, apiGet } from '$lib/api/client';
	import { toastStore } from '$lib/stores/toast.svelte';
	import type { DeckSummary, Game } from '$lib/types/api';
	import { getContext } from 'svelte';

	const getGame = getContext<() => Game | null>('game');
	let game = $derived(getGame());

	let decks = $state<DeckSummary[]>([]);
	let loading = $state(false);
	let loadError = $state(false);
	let createModalOpen = $state(false);
	let newDeckName = $state('');
	let creating = $state(false);
	let deletingId = $state<number | null>(null);
	let deleteConfirmId = $state<number | null>(null);

	// Plain (non-reactive) — avoids re-fetching unnecessarily
	let loadedGameId: string | null = null;

	$effect(() => {
		const id = page.params.id;
		if (!game || String(game.id) !== id) return;
		if (loadedGameId !== id) {
			loadedGameId = id;
			void loadDecks(id);
		}
	});

	async function loadDecks(id: string) {
		loading = true;
		loadError = false;
		try {
			const result = await apiGet<DeckSummary[]>(`/api/games/${id}/decks`);
			decks = result;
		} catch {
			loadError = true;
		} finally {
			loading = false;
		}
	}

	function openCreateModal() {
		newDeckName = '';
		createModalOpen = true;
	}

	function closeCreateModal() {
		createModalOpen = false;
	}

	async function createDeck() {
		if (creating || !game || !newDeckName.trim()) return;
		const gameId = game.id;
		creating = true;
		try {
			const created = await apiPost<DeckSummary>(`/api/games/${gameId}/decks`, {
				name: newDeckName.trim()
			});
			createModalOpen = false;
			toastStore.show('Deck created.', 'success');
			goto(`/dashboard/games/${gameId}/decks/${created.id}`);
		} catch (err) {
			const messages = err instanceof ApiError ? err.messages : ['Failed to create deck.'];
			toastStore.show(messages[0]);
		} finally {
			creating = false;
		}
	}

	async function deleteDeck(id: number) {
		if (!game || deletingId !== null) return;
		deletingId = id;
		try {
			await apiDelete(`/api/games/${game.id}/decks/${id}`);
			decks = decks.filter((d) => d.id !== id);
			deleteConfirmId = null;
			toastStore.show('Deck deleted.', 'success');
		} catch (err) {
			const messages = err instanceof ApiError ? err.messages : ['Failed to delete deck.'];
			toastStore.show(messages[0]);
		} finally {
			deletingId = null;
		}
	}

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString('en-US', {
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		});
	}
</script>

<svelte:head><title>Decks — Carddo</title></svelte:head>

<div class="space-y-5">
	<div class="flex items-center justify-between">
		<div>
			<h2 class="text-sm font-semibold text-slate-100">Decks</h2>
			<p class="mt-0.5 text-xs text-slate-500">Design and manage decks for this game.</p>
		</div>
		<button
			type="button"
			onclick={openCreateModal}
			class="flex items-center gap-1.5 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-indigo-500 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none"
		>
			<svg
				xmlns="http://www.w3.org/2000/svg"
				class="h-3.5 w-3.5"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
				stroke-width="2"
				aria-hidden="true"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
			</svg>
			New Deck
		</button>
	</div>

	{#if loadError}
		<div class="flex flex-col items-center justify-center py-16 text-center">
			<p class="text-sm text-slate-400">Failed to load decks.</p>
			<button
				type="button"
				onclick={() => {
					const id = page.params.id;
					if (id) void loadDecks(id);
				}}
				class="mt-3 text-sm text-indigo-400 transition hover:text-indigo-300"
			>
				Try again
			</button>
		</div>
	{:else if loading}
		<div class="grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-4">
			{#each [1, 2, 3, 4] as i (i)}
				<div class="aspect-[2/3] animate-pulse rounded-xl bg-slate-800"></div>
			{/each}
		</div>
	{:else if decks.length === 0}
		<div class="flex flex-col items-center justify-center py-16 text-center">
			<p class="text-sm text-slate-400">No decks yet. Create your first deck to start building.</p>
			<button
				type="button"
				onclick={openCreateModal}
				class="mt-4 flex items-center gap-1.5 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-indigo-500 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none"
			>
				New Deck
			</button>
		</div>
	{:else}
		<div class="grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-4">
			{#each decks as deck (deck.id)}
				<div
					class="group relative rounded-xl border border-slate-700/50 bg-[#1a1d27] p-4 transition hover:border-slate-600"
				>
					<a href="/dashboard/games/{page.params.id}/decks/{deck.id}" class="block">
						<p class="truncate text-sm font-medium text-slate-100">{deck.name}</p>
						<p class="mt-1 text-xs text-slate-500">Updated {formatDate(deck.updated_at)}</p>
					</a>
					<div class="mt-3 flex justify-end">
						{#if deleteConfirmId === deck.id}
							<div class="flex items-center gap-2">
								<span class="text-xs text-slate-400">Delete?</span>
								<button
									onclick={() => void deleteDeck(deck.id)}
									disabled={deletingId === deck.id}
									class="text-xs text-red-400 transition hover:text-red-300 disabled:opacity-50"
								>
									{deletingId === deck.id ? 'Deleting…' : 'Yes'}
								</button>
								<button
									onclick={() => (deleteConfirmId = null)}
									class="text-xs text-slate-500 transition hover:text-slate-300"
								>
									Cancel
								</button>
							</div>
						{:else}
							<button
								onclick={() => (deleteConfirmId = deck.id)}
								class="text-xs text-slate-600 transition hover:text-red-400"
							>
								Delete
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

{#if createModalOpen}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
		onkeydown={(e) => {
			if (e.key === 'Escape' && !creating) closeCreateModal();
		}}
	>
		<div
			class="fixed inset-0"
			aria-hidden="true"
			onclick={() => {
				if (!creating) closeCreateModal();
			}}
		></div>
		<div
			role="dialog"
			aria-modal="true"
			aria-labelledby="new-deck-modal-title"
			class="relative w-full max-w-sm rounded-xl border border-slate-700 bg-[#1a1d27] p-6 shadow-2xl"
		>
			<div class="mb-4 flex items-center justify-between">
				<h3 id="new-deck-modal-title" class="text-sm font-semibold text-slate-100">New Deck</h3>
				<button
					type="button"
					onclick={closeCreateModal}
					class="rounded-md p-1 text-slate-500 transition hover:bg-slate-700/60 hover:text-slate-300 disabled:pointer-events-none disabled:opacity-30"
					aria-label="Close"
					disabled={creating}
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

			<div class="space-y-3">
				<div>
					<label for="new-deck-name" class="mb-1.5 block text-xs font-medium text-slate-400">
						Name <span class="text-red-400">*</span>
					</label>
					<input
						id="new-deck-name"
						type="text"
						bind:value={newDeckName}
						placeholder="e.g. Starter Deck"
						class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
						onkeydown={(e) => {
							if (e.key === 'Enter') void createDeck();
						}}
					/>
				</div>
			</div>

			<div class="mt-5 flex justify-end gap-2">
				<button
					type="button"
					onclick={closeCreateModal}
					disabled={creating}
					class="rounded-lg border border-slate-600 px-4 py-2 text-xs font-medium text-slate-300 transition hover:border-slate-500 hover:text-slate-100 disabled:opacity-50"
				>
					Cancel
				</button>
				<button
					type="button"
					onclick={() => void createDeck()}
					disabled={creating || !newDeckName.trim()}
					class="flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
				>
					{#if creating}
						<svg
							class="h-3.5 w-3.5 animate-spin"
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
						Create Deck
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}
