<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { PUBLIC_API_URL } from '$env/static/public';
	import { apiGet } from '$lib/api/client';
	import { GameChannel, buildWsUrl } from '$lib/api/channel.svelte';
	import { authStore } from '$lib/stores/auth.svelte';
	import { toastStore } from '$lib/stores/toast.svelte';
	import { initWasm, validateMove } from '$lib/engine/wasm';
	import { findEntityZone, stripPrivateState } from '$lib/engine/state-utils';
	import type { DeckSummary, Game } from '$lib/types/api';
	import type { ConnectionStatus } from '$lib/types/channel';
	import type { Action } from '$lib/types/ditto.generated';
	import GameBoard from '$lib/components/game/GameBoard.svelte';
	import { getContext, onMount } from 'svelte';
	import { gameStore } from '$lib/stores/game.svelte';

	const getGame = getContext<() => Game | null>('game');
	let game = $derived(getGame());

	let decks = $state<DeckSummary[]>([]);
	let selectedDeckId = $state<number | null>(null);
	let loadingDecks = $state(false);
	let channel = $state<GameChannel | null>(null);

	let validDropTargets = $state<string[]>([]);

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
		loadingDecks = true;
		try {
			const result = await apiGet<DeckSummary[]>(`/api/games/${id}/decks`);
			decks = result;
			if (result.length === 1) {
				selectedDeckId = result[0].id;
			}
		} catch {
			toastStore.show('Failed to load decks.');
		} finally {
			loadingDecks = false;
		}
	}

	async function startPlaytest() {
		if (!game || selectedDeckId === null || !authStore.token || !authStore.currentUser) return;

		const localUser = authStore.currentUser;
		const localGame = game;
		const localDeckId = selectedDeckId;
		const roomId = `solo_${localUser.id}_${localGame.id}`;
		let ch: GameChannel | null = null;

		try {
			const wsUrl = buildWsUrl(PUBLIC_API_URL);
			ch = new GameChannel(authStore.token, wsUrl);
			channel = ch;

			await ch.connect(roomId, {
				game_id: localGame.id,
				deck_id: localDeckId
			});

			if (channel !== ch || !ch.gameState || !authStore.currentUser) {
				ch.disconnect();
				if (channel === ch) channel = null;
				return;
			}

			gameStore.initGame(ch.gameState, localUser.id);
		} catch {
			ch?.disconnect();
			if (channel === ch) channel = null;
			toastStore.show('Failed to connect to game channel.');
		}
	}

	function endTurn() {
		if (channel) gameStore.attemptMove('EndTurn', channel);
	}

	function disconnectChannel() {
		channel?.disconnect();
		channel = null;
		gameStore.reset();
	}

	function handleReturnToDashboard() {
		channel?.disconnect();
		channel = null;
		gameStore.reset();
		goto('/dashboard');
	}

	async function handleDrop(entityId: string, toZone: string) {
		if (!gameState || !channel) return;
		if (gameStore.pendingAction !== null) {
			toastStore.show('Action pending - please wait', 'info');
			return;
		}

		const capturedState = gameState;
		const capturedChannel = channel;
		const capturedPlayerId = currentPlayerId;

		const fromZone = findEntityZone(capturedState, entityId);
		if (!fromZone) return;

		const action: Action = {
			MoveEntity: {
				entity_id: entityId,
				from_zone: fromZone,
				to_zone: toZone,
				index: null
			}
		};

		try {
			const publicState = stripPrivateState(capturedState, capturedPlayerId);
			const result = await validateMove(publicState, action);

			const stateChanged = gameState !== capturedState || channel !== capturedChannel;
			const entityMoved = findEntityZone(gameState ?? capturedState, entityId) !== fromZone;
			if (stateChanged || entityMoved) {
				toastStore.show('Game state changed during validation. Please try again.');
				return;
			}

			if (!result.ok) {
				toastStore.show(result.message);
				return;
			}

			gameStore.attemptMove(action, capturedChannel);
		} catch {
			toastStore.show('Validation failed. Please try again.');
		}
	}

	$effect(() => {
		const ch = channel;
		return () => {
			ch?.disconnect();
			gameStore.reset();
		};
	});

	$effect(() => {
		const ch = channel;
		if (!ch?.gameState) return;
		gameStore.receiveResolution(ch.gameState);
	});

	$effect(() => {
		const rejection = channel?.lastRejection;
		if (!rejection) return;
		gameStore.receiveRejection(rejection);
	});

	$effect(() => {
		const over = channel?.gameOver;
		if (!over) return;
		gameStore.receiveGameOver(over);
	});

	let connectionStatus = $derived<ConnectionStatus>(channel?.connectionStatus ?? 'disconnected');
	let gameState = $derived(gameStore.optimisticState);
	let lastRejection = $derived(channel?.lastRejection ?? null);
	let errors = $derived(channel?.errors ?? []);
	let gameOver = $derived(gameStore.gameOver);

	const currentPlayerId = $derived(authStore.currentUser?.id ?? '');

	onMount(() => {
		void initWasm().catch(() => {
			toastStore.show('Failed to load game engine.');
		});
	});

	$effect(() => {
		if (gameState) {
			validDropTargets = Object.keys(gameState.zones);
		} else {
			validDropTargets = [];
		}
	});

	function statusColor(status: ConnectionStatus): string {
		switch (status) {
			case 'connected':
				return 'bg-green-500';
			case 'connecting':
				return 'bg-yellow-500';
			case 'error':
				return 'bg-red-500';
			default:
				return 'bg-slate-500';
		}
	}
</script>

<svelte:head><title>Playtest — Carddo</title></svelte:head>

<div class="space-y-5">
	<div class="flex items-center justify-between">
		<div>
			<h2 class="text-sm font-semibold text-slate-100">Playtest</h2>
			<p class="mt-0.5 text-xs text-slate-500">Test your game in real time.</p>
		</div>
		<div class="flex items-center gap-2">
			<span class="flex items-center gap-1.5 text-xs text-slate-400">
				<span class="inline-block h-2 w-2 rounded-full {statusColor(connectionStatus)}"></span>
				{connectionStatus}
			</span>
			{#if connectionStatus === 'connected'}
				<button
					type="button"
					onclick={disconnectChannel}
					class="rounded-lg border border-slate-600 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-slate-500 hover:text-slate-100"
				>
					Disconnect
				</button>
			{/if}
		</div>
	</div>

	{#if connectionStatus === 'disconnected'}
		<!-- Deck picker + connect -->
		{#if loadingDecks}
			<div class="py-16 text-center">
				<p class="text-sm text-slate-400">Loading decks…</p>
			</div>
		{:else if decks.length === 0}
			<div class="flex flex-col items-center justify-center py-16 text-center">
				<p class="text-sm text-slate-400">No decks available. Create a deck first.</p>
			</div>
		{:else}
			<div class="flex items-end gap-3">
				<div>
					<label for="deck-select" class="mb-1.5 block text-xs font-medium text-slate-400">
						Deck
					</label>
					<select
						id="deck-select"
						bind:value={selectedDeckId}
						class="rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
					>
						<option value={null}>Select a deck…</option>
						{#each decks as deck (deck.id)}
							<option value={deck.id}>{deck.name}</option>
						{/each}
					</select>
				</div>
				<button
					type="button"
					onclick={() => void startPlaytest()}
					disabled={selectedDeckId === null || connectionStatus !== 'disconnected'}
					class="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
				>
					Start Playtest
				</button>
			</div>
		{/if}
	{:else if connectionStatus === 'connecting'}
		<div class="py-16 text-center">
			<p class="text-sm text-slate-400">Connecting to game…</p>
		</div>
	{:else if connectionStatus === 'error'}
		<div class="flex flex-col items-center justify-center py-16 text-center">
			<p class="text-sm text-red-400">Connection error.</p>
			{#each errors as err, i (`${err.code}:${i}`)}
				<p class="mt-1 text-xs text-slate-500">{err.message} ({err.code})</p>
			{/each}
			<button
				type="button"
				onclick={disconnectChannel}
				class="mt-3 text-sm text-indigo-400 transition hover:text-indigo-300"
			>
				Disconnect
			</button>
		</div>
	{:else if connectionStatus === 'connected'}
		<!-- Game state display -->
		{#if lastRejection}
			<div class="rounded-lg border border-red-800/50 bg-red-950/30 px-4 py-3">
				<p class="text-xs font-medium text-red-400">Action rejected</p>
				{#each lastRejection.errors as err, i (`${err.code}:${i}`)}
					<p class="mt-0.5 text-xs text-red-300/80">{err.message}</p>
				{/each}
			</div>
		{/if}

		{#if gameState}
			<GameBoard
				{gameState}
				{currentPlayerId}
				{validDropTargets}
				{gameOver}
				onDrop={handleDrop}
				onReturnToDashboard={handleReturnToDashboard}
			/>

			<div class="flex gap-2 pt-2">
				<button
					type="button"
					onclick={endTurn}
					class="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white transition hover:bg-indigo-500"
				>
					End Turn
				</button>
			</div>
		{:else}
			<div class="py-16 text-center">
				<p class="text-sm text-slate-400">Waiting for game state…</p>
			</div>
		{/if}
	{/if}
</div>
