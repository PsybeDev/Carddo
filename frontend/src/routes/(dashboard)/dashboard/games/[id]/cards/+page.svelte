<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { ApiError, apiGet, apiPost } from '$lib/api/client';
	import CardThumbnail from '$lib/components/CardThumbnail.svelte';
	import { toastStore } from '$lib/stores/toast.svelte';
	import type { Card, Game } from '$lib/types/api';
	import { getContext } from 'svelte';

	const getGame = getContext<() => Game | null>('game');
	let game = $derived(getGame());

	let cards = $state<Card[]>([]);
	let search = $state('');
	let loading = $state(false);
	let loadError = $state(false);
	let createModalOpen = $state(false);
	let newName = $state('');
	let newCardType = $state('');
	let creating = $state(false);

	// Plain (non-reactive) variable — avoids triggering search effect when game loads
	let loadedGameId: string | null = null;
	let debounceTimer: ReturnType<typeof setTimeout> | null = null;
	let abortController: AbortController | null = null;
	// Track the latest request params to prevent stale results
	let latestRequestKey: string | null = null;

	$effect(() => {
		const id = page.params.id;
		const term = search;

		if (!game || String(game.id) !== id) return;

		if (loadedGameId !== id) {
			// New game — fetch immediately, don't debounce
			loadedGameId = id;
			if (debounceTimer) clearTimeout(debounceTimer);
			void loadCards(id, term);
			return;
		}

		// Same game, search changed — debounce
		if (debounceTimer) clearTimeout(debounceTimer);
		debounceTimer = setTimeout(() => void loadCards(id, term), 300);

		return () => {
			if (debounceTimer) clearTimeout(debounceTimer);
			if (abortController) {
				abortController.abort();
				abortController = null;
			}
		};
	});

	async function loadCards(id: string, term: string) {
		// Cancel any in-flight request
		if (abortController) {
			abortController.abort();
		}
		abortController = new AbortController();

		const requestKey = `${id}:${term}`;
		latestRequestKey = requestKey;

		loading = true;
		loadError = false;
		try {
			const path = term.trim()
				? `/api/games/${id}/cards?search=${encodeURIComponent(term.trim())}`
				: `/api/games/${id}/cards`;
			const result = await apiGet<Card[]>(path, abortController.signal);
			// Only update state if this is still the latest request
			if (latestRequestKey === requestKey) {
				cards = result;
			}
		} catch (err) {
			// Don't show error for aborted requests
			if (err instanceof Error && err.name === 'AbortError') {
				return;
			}
			// Only update error state if this is still the latest request
			if (latestRequestKey === requestKey) {
				loadError = true;
			}
		} finally {
			// Only clear loading if this is still the latest request
			if (latestRequestKey === requestKey) {
				loading = false;
			}
		}
	}

	function openCreateModal() {
		newName = '';
		newCardType = '';
		createModalOpen = true;
	}

	function closeCreateModal() {
		createModalOpen = false;
	}

	async function createCard() {
		if (creating || !game || !newName.trim() || !newCardType.trim()) return;
		const gameId = game.id;
		creating = true;
		try {
			const created = await apiPost<Card>(`/api/games/${gameId}/cards`, {
				name: newName.trim(),
				card_type: newCardType.trim(),
				background_color: '#1e2235'
			});
			goto(`/dashboard/games/${gameId}/cards/${created.id}`);
		} catch (err) {
			const messages = err instanceof ApiError ? err.messages : ['Failed to create card.'];
			toastStore.show(messages[0]);
		} finally {
			creating = false;
		}
	}
</script>

<svelte:head><title>Cards — Carddo</title></svelte:head>

<div class="space-y-5">
	<div class="flex items-center justify-between">
		<div>
			<h2 class="text-sm font-semibold text-slate-100">Cards</h2>
			<p class="mt-0.5 text-xs text-slate-500">Design and manage cards for this game.</p>
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
			New Card
		</button>
	</div>

	<!-- Search -->
	<input
		type="search"
		bind:value={search}
		placeholder="Search cards…"
		class="w-full max-w-xs rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
		aria-label="Search cards"
	/>

	{#if loadError}
		<div class="flex flex-col items-center justify-center py-16 text-center">
			<p class="text-sm text-slate-400">Failed to load cards.</p>
			<button
				type="button"
				onclick={() => {
					const id = page.params.id;
					if (id) void loadCards(id, search);
				}}
				class="mt-3 text-sm text-indigo-400 transition hover:text-indigo-300"
			>
				Try again
			</button>
		</div>
	{:else if loading}
		<div class="grid grid-cols-[repeat(auto-fill,minmax(140px,1fr))] gap-4">
			{#each [1, 2, 3, 4] as i (i)}
				<div class="aspect-[2/3] animate-pulse rounded-xl bg-slate-800"></div>
			{/each}
		</div>
	{:else if cards.length === 0}
		<div class="flex flex-col items-center justify-center py-16 text-center">
			<p class="text-sm text-slate-400">
				{search.trim() ? 'No cards match your search.' : 'No cards yet. Create your first card.'}
			</p>
		</div>
	{:else}
		<div class="grid grid-cols-[repeat(auto-fill,minmax(140px,1fr))] gap-4">
			{#each cards as card (card.id)}
				<a
					href="/dashboard/games/{page.params.id}/cards/{card.id}"
					class="block rounded-xl transition hover:opacity-90 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none"
				>
					<CardThumbnail {card} />
				</a>
			{/each}
		</div>
	{/if}
</div>

<!-- Create card modal -->
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
			aria-labelledby="new-card-modal-title"
			class="relative w-full max-w-sm rounded-xl border border-slate-700 bg-[#1a1d27] p-6 shadow-2xl"
		>
			<div class="mb-4 flex items-center justify-between">
				<h3 id="new-card-modal-title" class="text-sm font-semibold text-slate-100">New Card</h3>
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
					<label for="new-card-name" class="mb-1.5 block text-xs font-medium text-slate-400">
						Name <span class="text-red-400">*</span>
					</label>
					<input
						id="new-card-name"
						type="text"
						bind:value={newName}
						placeholder="e.g. Fire Elemental"
						class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
						onkeydown={(e) => {
							if (e.key === 'Enter') void createCard();
						}}
					/>
				</div>
				<div>
					<label for="new-card-type" class="mb-1.5 block text-xs font-medium text-slate-400">
						Card Type <span class="text-red-400">*</span>
					</label>
					<input
						id="new-card-type"
						type="text"
						bind:value={newCardType}
						placeholder="e.g. creature, spell"
						class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
						onkeydown={(e) => {
							if (e.key === 'Enter') void createCard();
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
					onclick={() => void createCard()}
					disabled={creating || !newName.trim() || !newCardType.trim()}
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
						Create Card
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}
