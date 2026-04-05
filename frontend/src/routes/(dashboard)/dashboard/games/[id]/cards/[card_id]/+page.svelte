<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { ApiError, apiDelete, apiGet, apiPatch } from '$lib/api/client';
	import RuleBuilder from '$lib/components/builder/RuleBuilder.svelte';
	import { normalizeRule } from '$lib/components/builder/utils';
	import { toastStore } from '$lib/stores/toast.svelte';
	import type { Card, Game } from '$lib/types/api';
	import { normalizeConfig } from '$lib/utils/game-config';
	import { getContext } from 'svelte';

	const getGame = getContext<() => Game | null>('game');
	let game = $derived(getGame());

	let card = $state<Card | null>(null);
	let loadError = $state(false);
	let cardInitializedFor = $state<string | null>(null);

	// Editable fields
	let name = $state('');
	let cardType = $state('');
	let bgColor = $state('#1e2235');
	let properties = $state<Record<string, number>>({});
	let abilities = $state<Card['abilities']>([]);

	let saving = $state(false);
	let deleteConfirm = $state(false);
	let deleting = $state(false);

	// Normalized game config for RuleBuilder
	let gameConfig = $derived(normalizeConfig(game?.config));

	$effect(() => {
		const cardId = page.params.card_id;
		const gameId = page.params.id;
		const key = `${gameId}:${cardId}`;
		if (game && gameId && cardId && String(game.id) === gameId && cardInitializedFor !== key) {
			cardInitializedFor = key;
			void loadCard(gameId, cardId);
		}
	});

	async function loadCard(gameId: string, cardId: string) {
		loadError = false;
		card = null;
		try {
			const loaded = await apiGet<Card>(`/api/games/${gameId}/cards/${cardId}`);
			if (page.params.card_id !== cardId) return;
			card = loaded;
			name = loaded.name;
			cardType = loaded.card_type;
			bgColor = loaded.background_color ?? '#1e2235';
			// Merge game config property defaults with saved values
			const merged: Record<string, number> = {};
			for (const prop of gameConfig.properties) {
				merged[prop.name] = loaded.properties[prop.name] ?? prop.default;
			}
			// Preserve any extra properties not in current config
			for (const [k, v] of Object.entries(loaded.properties)) {
				if (!(k in merged)) merged[k] = v;
			}
			properties = merged;
			abilities = loaded.abilities.map(normalizeRule);
		} catch (err) {
			if (page.params.card_id !== cardId) return;
			if (err instanceof ApiError && err.status === 404) {
				toastStore.show('Card not found.');
				goto(`/dashboard/games/${gameId}/cards`);
			} else {
				loadError = true;
			}
		}
	}

	async function save() {
		if (!card || saving) return;
		const { game_id, id } = card;
		saving = true;
		try {
			const updated = await apiPatch<Card>(`/api/games/${game_id}/cards/${id}`, {
				name: name.trim() || card.name,
				card_type: cardType.trim() || card.card_type,
				background_color: bgColor,
				properties,
				abilities
			});
			if (page.params.card_id !== String(id)) return;
			card = updated;
			toastStore.show('Card saved.', 'success');
		} catch {
			if (page.params.card_id !== String(id)) return;
			toastStore.show('Failed to save card.');
		} finally {
			saving = false;
		}
	}

	async function deleteCard() {
		if (!card || deleting) return;
		const { game_id, id } = card;
		deleting = true;
		try {
			await apiDelete(`/api/games/${game_id}/cards/${id}`);
			goto(`/dashboard/games/${game_id}/cards`);
		} catch {
			toastStore.show('Failed to delete card.');
			deleting = false;
		}
	}

	function setProperty(name: string, raw: string) {
		const parsed = Number(raw);
		properties = { ...properties, [name]: raw === '' || !Number.isFinite(parsed) ? 0 : parsed };
	}
</script>

<svelte:head><title>{card ? card.name : 'Card'} — Carddo</title></svelte:head>

{#if loadError}
	<div class="flex flex-col items-center justify-center py-16 text-center">
		<p class="text-sm text-slate-400">Failed to load card.</p>
		<button
			type="button"
			onclick={() => {
				const id = page.params.id;
				const cid = page.params.card_id;
				if (id && cid) void loadCard(id, cid);
			}}
			class="mt-3 text-sm text-indigo-400 transition hover:text-indigo-300"
		>
			Try again
		</button>
	</div>
{:else if card}
	<div class="space-y-6">
		<!-- Core fields -->
		<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
			<h2 class="mb-4 text-sm font-semibold text-slate-100">Card Details</h2>
			<div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
				<div>
					<label for="card-name" class="mb-1.5 block text-xs font-medium text-slate-400">Name</label
					>
					<input
						id="card-name"
						type="text"
						bind:value={name}
						class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
					/>
				</div>
				<div>
					<label for="card-type" class="mb-1.5 block text-xs font-medium text-slate-400"
						>Card Type</label
					>
					<input
						id="card-type"
						type="text"
						bind:value={cardType}
						placeholder="e.g. creature, spell"
						class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
					/>
				</div>
				<div>
					<label for="card-color" class="mb-1.5 block text-xs font-medium text-slate-400"
						>Background Colour</label
					>
					<div class="flex items-center gap-3">
						<input
							id="card-color"
							type="color"
							bind:value={bgColor}
							class="h-9 w-14 cursor-pointer rounded-lg border border-slate-600 bg-slate-800/60 p-0.5 transition focus:ring-1 focus:ring-indigo-500/50 focus:outline-none"
						/>
						<span class="font-mono text-sm text-slate-400">{bgColor}</span>
					</div>
				</div>
			</div>
		</div>

		<!-- Properties panel -->
		{#if gameConfig.properties.length > 0}
			<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
				<div class="mb-4">
					<h2 class="text-sm font-semibold text-slate-100">Properties</h2>
					<p class="mt-0.5 text-xs text-slate-500">Numeric stats defined by your game config.</p>
				</div>
				<div class="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-3">
					{#each gameConfig.properties as prop, i (prop.name)}
						<div>
							<label for="prop-{i}" class="mb-1 block text-xs font-medium text-slate-400"
								>{prop.name}</label
							>
							<input
								id="prop-{i}"
								type="number"
								value={properties[prop.name] ?? prop.default}
								oninput={(e) => setProperty(prop.name, (e.currentTarget as HTMLInputElement).value)}
								class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
							/>
						</div>
					{/each}
				</div>
			</div>
		{/if}

		<!-- Abilities (RuleBuilder) -->
		<RuleBuilder
			{gameConfig}
			bind:rules={abilities}
			title="Abilities"
			description="ECA rules that trigger during gameplay when this card is in play."
		/>

		<!-- Actions row -->
		<div class="flex items-center justify-between">
			<div>
				{#if deleteConfirm}
					<div class="flex items-center gap-2">
						<span class="text-xs text-slate-400">Delete this card?</span>
						<button
							type="button"
							onclick={() => void deleteCard()}
							disabled={deleting}
							class="rounded-lg bg-red-600/80 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-red-500 disabled:opacity-50"
						>
							{deleting ? 'Deleting…' : 'Yes, delete'}
						</button>
						<button
							type="button"
							onclick={() => (deleteConfirm = false)}
							disabled={deleting}
							class="rounded-lg border border-slate-600 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-slate-500 disabled:opacity-50"
						>
							Cancel
						</button>
					</div>
				{:else}
					<button
						type="button"
						onclick={() => (deleteConfirm = true)}
						class="rounded-lg border border-red-500/30 px-3 py-1.5 text-xs font-medium text-red-400 transition hover:border-red-500/60 hover:bg-red-500/10"
					>
						Delete Card
					</button>
				{/if}
			</div>

			<button
				type="button"
				onclick={() => void save()}
				disabled={saving}
				class="flex items-center gap-2 rounded-lg bg-indigo-600 px-5 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none active:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-50"
			>
				{#if saving}
					<svg
						class="h-4 w-4 animate-spin"
						xmlns="http://www.w3.org/2000/svg"
						fill="none"
						viewBox="0 0 24 24"
						aria-hidden="true"
					>
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"
						></circle>
						<path
							class="opacity-75"
							fill="currentColor"
							d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
						></path>
					</svg>
					Saving…
				{:else}
					Save Card
				{/if}
			</button>
		</div>
	</div>
{:else}
	<!-- Loading skeleton -->
	<div class="animate-pulse space-y-4">
		<div class="h-32 rounded-xl bg-slate-800"></div>
		<div class="h-24 rounded-xl bg-slate-800"></div>
		<div class="h-40 rounded-xl bg-slate-800"></div>
	</div>
{/if}
