<script lang="ts">
	import { page } from '$app/state';
	import { ApiError, apiGet, apiPatch } from '$lib/api/client';
	import CardThumbnail from '$lib/components/CardThumbnail.svelte';
	import { toastStore } from '$lib/stores/toast.svelte';
	import type { Card, Deck, DeckEntry, Game } from '$lib/types/api';
	import { getContext } from 'svelte';

	const getGame = getContext<() => Game | null>('game');
	let game = $derived(getGame());

	// Card library (left pane)
	let cards = $state<Card[]>([]);
	let search = $state('');
	let cardsLoading = $state(false);
	let cardsError = $state(false);

	// Deck (right pane)
	let deck = $state<Deck | null>(null);
	let deckLoading = $state(false);
	let deckError = $state(false);
	let deckName = $state('');
	let entries = $state<DeckEntry[]>([]);
	let saving = $state(false);

	// Derived
	let totalCards = $derived(entries.reduce((sum, e) => sum + e.quantity, 0));

	// Plain non-reactive vars
	let loadedDeckKey: string | null = null;
	let loadedCardsKey: string | null = null;
	let debounceTimer: ReturnType<typeof setTimeout> | null = null;
	let abortController: AbortController | null = null;
	let latestRequestKey: string | null = null;

	$effect(() => {
		const deckId = (page.params as Record<string, string>)['deck_id'];
		const gameId = (page.params as Record<string, string>)['id'];
		const key = `${gameId}:${deckId}`;
		if (!game || String(game.id) !== gameId || !deckId) return;
		if (loadedDeckKey !== key) {
			loadedDeckKey = key;
			void loadDeck(gameId, deckId);
		}
	});

	async function loadDeck(gameId: string, deckId: string) {
		deckLoading = true;
		deckError = false;
		try {
			const loaded = await apiGet<Deck>(`/api/games/${gameId}/decks/${deckId}`);
			deck = loaded;
			deckName = loaded.name;
			entries = loaded.entries ? [...loaded.entries] : [];
		} catch {
			deckError = true;
		} finally {
			deckLoading = false;
		}
	}

	$effect(() => {
		const id = page.params.id;
		const term = search;
		if (!game || String(game.id) !== id) return;

		const cardsKey = `${id}:${term}`;
		if (loadedCardsKey === null) {
			// First load — immediate
			loadedCardsKey = cardsKey;
			void loadCards(id, term);
			return;
		}
		if (loadedCardsKey === cardsKey) return;

		if (debounceTimer) clearTimeout(debounceTimer);
		debounceTimer = setTimeout(() => {
			loadedCardsKey = cardsKey;
			void loadCards(id, term);
		}, 300);

		return () => {
			if (debounceTimer) clearTimeout(debounceTimer);
			if (abortController) {
				abortController.abort();
				abortController = null;
			}
		};
	});

	async function loadCards(id: string, term: string) {
		if (abortController) abortController.abort();
		abortController = new AbortController();
		const requestKey = `${id}:${term}`;
		latestRequestKey = requestKey;

		cardsLoading = true;
		cardsError = false;
		try {
			const path = term.trim()
				? `/api/games/${id}/cards?search=${encodeURIComponent(term.trim())}`
				: `/api/games/${id}/cards`;
			const result = await apiGet<Card[]>(path, abortController.signal);
			if (latestRequestKey === requestKey) cards = result;
		} catch (err) {
			if (err instanceof Error && err.name === 'AbortError') return;
			if (latestRequestKey === requestKey) cardsError = true;
		} finally {
			if (latestRequestKey === requestKey) cardsLoading = false;
		}
	}

	function addCard(card: Card) {
		const existing = entries.find((e) => e.card_id === card.id);
		if (existing) {
			existing.quantity += 1;
			entries = [...entries];
		} else {
			entries = [...entries, { card_id: card.id, quantity: 1, card }];
		}
	}

	function increment(entry: DeckEntry) {
		entry.quantity += 1;
		entries = [...entries];
	}

	function decrement(entry: DeckEntry) {
		if (entry.quantity <= 1) {
			entries = entries.filter((e) => e.card_id !== entry.card_id);
		} else {
			entry.quantity -= 1;
			entries = [...entries];
		}
	}

	function removeEntry(entry: DeckEntry) {
		entries = entries.filter((e) => e.card_id !== entry.card_id);
	}

	async function saveDeck() {
		if (!deck || saving) return;
		saving = true;
		try {
			const updated = await apiPatch<Deck>(`/api/games/${game!.id}/decks/${deck.id}`, {
				entries: entries.map((e) => ({ card_id: e.card_id, quantity: e.quantity }))
			});
			entries = updated.entries ? [...updated.entries] : [];
			toastStore.show('Deck saved.', 'success');
		} catch (err) {
			if (err instanceof ApiError) toastStore.show(err.messages[0]);
			else toastStore.show('Failed to save deck.');
		} finally {
			saving = false;
		}
	}

	async function saveName() {
		if (!deck || !game) return;
		const trimmed = deckName.trim();
		if (!trimmed) {
			deckName = deck.name;
			return;
		}
		if (trimmed === deck.name) return;
		try {
			await apiPatch(`/api/games/${game.id}/decks/${deck.id}`, { name: trimmed });
			deck = { ...deck, name: trimmed };
			deckName = trimmed;
		} catch (err) {
			if (err instanceof ApiError) toastStore.show(err.messages[0]);
			deckName = deck.name;
		}
	}
</script>

<svelte:head>
	<title>{deckName || 'Deck'} — Deck Builder — Carddo</title>
</svelte:head>

<div class="mb-4">
	<a
		href="/dashboard/games/{page.params.id}/decks"
		class="text-xs text-slate-500 transition hover:text-slate-300"
	>
		&larr; Back to Decks
	</a>
</div>

{#if deckError}
	<div class="flex flex-col items-center justify-center py-16 text-center">
		<p class="text-sm text-slate-400">Failed to load deck.</p>
		<button
			onclick={() =>
				void loadDeck(
					(page.params as Record<string, string>).id,
					(page.params as Record<string, string>).deck_id
				)}
			class="mt-4 rounded-md bg-indigo-600 px-4 py-2 text-sm text-white hover:bg-indigo-500"
			>Try again</button
		>
	</div>
{:else}
	<div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
		<div class="space-y-4">
			<h2 class="text-sm font-semibold text-slate-100">Card Library</h2>
			<input
				type="search"
				bind:value={search}
				placeholder="Search cards&hellip;"
				class="w-full rounded-md border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder-slate-400 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 focus:outline-none"
			/>

			{#if cardsError}
				<p class="text-sm text-red-400">Failed to load cards.</p>
			{:else if cardsLoading}
				<div class="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-3">
					{#each Array(4) as _, i (i)}
						<div class="h-40 w-full animate-pulse rounded-xl bg-slate-800"></div>
					{/each}
				</div>
			{:else if cards.length === 0}
				<p class="text-sm text-slate-400">
					No cards found. <a
						href="/dashboard/games/{page.params.id}/cards"
						class="text-indigo-400 hover:text-indigo-300">Create cards first.</a
					>
				</p>
			{:else}
				<div class="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-3">
					{#each cards as card (card.id)}
						<button
							onclick={() => addCard(card)}
							class="block w-full rounded-xl transition hover:opacity-80 hover:ring-2 hover:ring-indigo-500/50 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none"
							aria-label="Add {card.name} to deck"
						>
							<CardThumbnail {card} />
						</button>
					{/each}
				</div>
			{/if}
		</div>

		<div class="space-y-4">
			{#if deckLoading}
				<div class="h-8 w-48 animate-pulse rounded bg-slate-800"></div>
			{:else if deck}
				<div class="flex items-center justify-between">
					<input
						type="text"
						bind:value={deckName}
						onblur={() => void saveName()}
						onkeydown={(e) => {
							if (e.key === 'Enter') e.currentTarget.blur();
							if (e.key === 'Escape') {
								deckName = deck!.name;
								e.currentTarget.blur();
							}
						}}
						class="rounded-md border border-transparent bg-transparent px-2 py-1 text-base font-semibold text-slate-100 transition hover:border-slate-600 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 focus:outline-none"
						aria-label="Deck name"
					/>
					<span class="text-xs text-slate-500"
						>{totalCards} {totalCards === 1 ? 'card' : 'cards'}</span
					>
				</div>

				{#if entries.length === 0}
					<p class="py-8 text-center text-sm text-slate-500">
						No cards in deck. Click cards in the library to add them.
					</p>
				{:else}
					<div class="space-y-2">
						{#each entries as entry (entry.card_id)}
							<div
								class="flex items-center gap-3 rounded-lg border border-slate-700/50 bg-[#1a1d27] p-2"
							>
								<div class="w-10 shrink-0">
									<CardThumbnail card={entry.card} />
								</div>
								<div class="min-w-0 flex-1">
									<p class="truncate text-sm text-slate-100">{entry.card.name}</p>
									<p class="text-xs text-slate-500">{entry.card.card_type}</p>
								</div>
								<div class="flex shrink-0 items-center gap-1">
									<button
										onclick={() => decrement(entry)}
										class="flex h-6 w-6 items-center justify-center rounded bg-slate-700 text-sm text-slate-300 transition hover:bg-slate-600"
										aria-label="Decrease quantity">&minus;</button
									>
									<span class="w-6 text-center text-sm text-slate-100">{entry.quantity}</span>
									<button
										onclick={() => increment(entry)}
										class="flex h-6 w-6 items-center justify-center rounded bg-slate-700 text-sm text-slate-300 transition hover:bg-slate-600"
										aria-label="Increase quantity">+</button
									>
									<button
										onclick={() => removeEntry(entry)}
										class="ml-1 flex h-6 w-6 items-center justify-center rounded bg-slate-700 text-sm text-slate-400 transition hover:bg-red-900/60 hover:text-red-400"
										aria-label="Remove {entry.card.name} from deck"
									>
										&times;
									</button>
								</div>
							</div>
						{/each}
					</div>
				{/if}

				<div class="flex justify-end pt-2">
					<button
						onclick={() => void saveDeck()}
						disabled={saving}
						class="flex items-center gap-2 rounded-lg bg-indigo-600 px-5 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
					>
						{#if saving}
							<svg
								class="h-4 w-4 animate-spin"
								xmlns="http://www.w3.org/2000/svg"
								fill="none"
								viewBox="0 0 24 24"
								><circle
									class="opacity-25"
									cx="12"
									cy="12"
									r="10"
									stroke="currentColor"
									stroke-width="4"
								></circle><path
									class="opacity-75"
									fill="currentColor"
									d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
								></path></svg
							>
							Saving&hellip;
						{:else}
							Save Deck
						{/if}
					</button>
				</div>
			{:else}
				<div class="animate-pulse space-y-3">
					<div class="h-8 w-48 rounded bg-slate-800"></div>
					<div class="h-16 rounded-lg bg-slate-800"></div>
					<div class="h-16 rounded-lg bg-slate-800"></div>
				</div>
			{/if}
		</div>
	</div>
{/if}
