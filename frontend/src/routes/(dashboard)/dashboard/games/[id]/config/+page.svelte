<script lang="ts">
	import { page } from '$app/state';
	import { apiPatch } from '$lib/api/client';
	import { toastStore } from '$lib/stores/toast.svelte';
	import type { GameConfig, ZoneConfig, Game } from '$lib/types/api';
	import { getContext } from 'svelte';

	const getGame = getContext<() => Game | null>('game');
	let game = $derived(getGame());

	let config = $state<GameConfig>({ zones: [], properties: [], rules: [], win_conditions: [] });
	let configInitializedFor = $state<string | null>(null);
	let saving = $state(false);

	let zoneKeys = $state<number[]>([]);
	let propKeys = $state<number[]>([]);
	let _nextKey = 0;

	function normalizeZones(value: unknown): GameConfig['zones'] {
		if (!Array.isArray(value)) return [];
		return value.map((z) => {
			const obj = z && typeof z === 'object' ? (z as Record<string, unknown>) : {};
			const name = typeof obj.name === 'string' ? obj.name : '';
			const vis = typeof obj.visibility === 'string' ? obj.visibility : 'Public';
			const visibility = (
				vis === 'Public' || vis === 'OwnerOnly' || vis === 'Hidden' ? vis : 'Public'
			) as ZoneConfig['visibility'];
			const capacityRaw = obj.capacity;
			const capacity =
				typeof capacityRaw === 'number' && Number.isFinite(capacityRaw) ? capacityRaw : null;
			return { name, visibility, capacity };
		});
	}

	function normalizeProperties(value: unknown): GameConfig['properties'] {
		if (!Array.isArray(value)) return [];
		return value.map((p) => {
			const obj = p && typeof p === 'object' ? (p as Record<string, unknown>) : {};
			const name = typeof obj.name === 'string' ? obj.name : '';
			const defaultRaw = obj.default;
			const defaultValue =
				typeof defaultRaw === 'number' && Number.isFinite(defaultRaw) ? defaultRaw : 0;
			return { name, default: defaultValue };
		});
	}

	$effect(() => {
		const id = page.params.id;
		if (game && String(game.id) === id && configInitializedFor !== id) {
			const c = game.config;
			config = {
				zones: normalizeZones(c.zones),
				properties: normalizeProperties(c.properties),
				rules: Array.isArray(c.rules) ? [...c.rules] : [],
				win_conditions: Array.isArray(c.win_conditions) ? [...c.win_conditions] : []
			};
			zoneKeys = config.zones.map(() => ++_nextKey);
			propKeys = config.properties.map(() => ++_nextKey);
			configInitializedFor = id;
		}
	});

	let hasEmptyName = $derived(
		config.zones.some((z) => !z.name.trim()) || config.properties.some((p) => !p.name.trim())
	);

	let hasDuplicateZoneName = $derived(() => {
		const names = config.zones.map((z) => z.name.trim()).filter(Boolean);
		return new Set(names).size !== names.length;
	});

	let canSave = $derived(
		!hasEmptyName && !hasDuplicateZoneName() && config.zones.length > 0 && !saving
	);

	function addZone() {
		config.zones = [...config.zones, { name: '', visibility: 'Public', capacity: null }];
		zoneKeys = [...zoneKeys, ++_nextKey];
	}

	function removeZone(i: number) {
		config.zones = config.zones.filter((_, idx) => idx !== i);
		zoneKeys = zoneKeys.filter((_, idx) => idx !== i);
	}

	function setZoneCapacity(i: number, raw: string) {
		let capacity: number | null;
		if (raw === '') {
			capacity = null;
		} else {
			const parsed = Number(raw);
			capacity = !Number.isFinite(parsed) ? null : Math.max(0, parsed);
		}
		config.zones[i] = { ...config.zones[i], capacity };
	}

	function addProperty() {
		config.properties = [...config.properties, { name: '', default: 0 }];
		propKeys = [...propKeys, ++_nextKey];
	}

	function removeProperty(i: number) {
		config.properties = config.properties.filter((_, idx) => idx !== i);
		propKeys = propKeys.filter((_, idx) => idx !== i);
	}

	function setPropertyDefault(i: number, raw: string) {
		const parsed = Number(raw);
		config.properties[i] = {
			...config.properties[i],
			default: raw === '' || !Number.isFinite(parsed) ? 0 : parsed
		};
	}

	async function save() {
		if (!game || !canSave) return;
		const gameId = game.id;
		saving = true;
		try {
			const mergedConfig = {
				...game.config,
				zones: config.zones,
				properties: config.properties
			};
			await apiPatch<Game>(`/api/games/${gameId}`, { config: mergedConfig });
			if (page.params.id !== String(gameId)) return;
			toastStore.show('Configuration saved.', 'success');
		} catch {
			if (page.params.id !== String(gameId)) return;
			toastStore.show('Failed to save configuration.');
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head><title>Configure — Carddo</title></svelte:head>

<div class="space-y-6">
	<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
		<div class="mb-4 flex items-center justify-between">
			<div>
				<h2 class="text-sm font-semibold text-slate-100">Zones</h2>
				<p class="mt-0.5 text-xs text-slate-500">Physical or logical areas of the game board.</p>
			</div>
			<button
				type="button"
				onclick={addZone}
				class="flex items-center gap-1.5 rounded-lg border border-slate-600/60 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-indigo-500/50 hover:bg-indigo-600/10 hover:text-indigo-300"
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
				Add Zone
			</button>
		</div>

		{#if config.zones.length > 0}
			<div class="mb-2 grid grid-cols-[1fr_150px_130px_36px] items-center gap-3 px-1">
				<span class="text-xs font-medium tracking-wide text-slate-500 uppercase">Name</span>
				<span class="text-xs font-medium tracking-wide text-slate-500 uppercase">Visibility</span>
				<span class="text-xs font-medium tracking-wide text-slate-500 uppercase">Capacity</span>
				<span></span>
			</div>

			<div class="space-y-2">
				{#each config.zones as zone, i (zoneKeys[i])}
					<div class="grid grid-cols-[1fr_150px_130px_36px] items-center gap-3">
						<input
							type="text"
							bind:value={zone.name}
							placeholder="e.g. hand, graveyard"
							aria-label={`Zone ${i + 1} name`}
							class="w-full rounded-lg border px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:ring-1 focus:ring-indigo-500/50
								{zone.name.trim() === ''
								? 'border-red-500/50 bg-red-950/20 focus:border-red-500'
								: 'border-slate-600 bg-slate-800/60 focus:border-indigo-500'}"
						/>
						<select
							bind:value={zone.visibility}
							aria-label={`Zone ${i + 1} visibility`}
							class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
						>
							<option value="Public">Public</option>
							<option value="OwnerOnly">Owner only</option>
							<option value="Hidden">Hidden</option>
						</select>
						<input
							type="number"
							min="0"
							step="1"
							placeholder="∞"
							value={zone.capacity ?? ''}
							aria-label={`Zone ${i + 1} capacity`}
							oninput={(e) => setZoneCapacity(i, (e.currentTarget as HTMLInputElement).value)}
							class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
						/>
						<button
							type="button"
							onclick={() => removeZone(i)}
							aria-label="Remove zone"
							class="flex h-9 w-9 items-center justify-center rounded-lg text-slate-500 transition hover:bg-red-500/10 hover:text-red-400"
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
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
								/>
							</svg>
						</button>
					</div>
				{/each}
			</div>
		{:else}
			<p class="py-6 text-center text-sm text-slate-500">
				No zones yet. Add one to define your game board.
			</p>
		{/if}
	</div>

	<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
		<div class="mb-4 flex items-center justify-between">
			<div>
				<h2 class="text-sm font-semibold text-slate-100">Properties</h2>
				<p class="mt-0.5 text-xs text-slate-500">
					Entity stats tracked by the engine (e.g. health, attack).
				</p>
			</div>
			<button
				type="button"
				onclick={addProperty}
				class="flex items-center gap-1.5 rounded-lg border border-slate-600/60 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-indigo-500/50 hover:bg-indigo-600/10 hover:text-indigo-300"
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
				Add Property
			</button>
		</div>

		{#if config.properties.length > 0}
			<div class="mb-2 grid grid-cols-[1fr_150px_36px] items-center gap-3 px-1">
				<span class="text-xs font-medium tracking-wide text-slate-500 uppercase">Name</span>
				<span class="text-xs font-medium tracking-wide text-slate-500 uppercase">Default</span>
				<span></span>
			</div>

			<div class="space-y-2">
				{#each config.properties as prop, i (propKeys[i])}
					<div class="grid grid-cols-[1fr_150px_36px] items-center gap-3">
						<input
							type="text"
							bind:value={prop.name}
							placeholder="e.g. health, attack"
							aria-label={`Property ${i + 1} name`}
							class="w-full rounded-lg border px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:ring-1 focus:ring-indigo-500/50
								{prop.name.trim() === ''
								? 'border-red-500/50 bg-red-950/20 focus:border-red-500'
								: 'border-slate-600 bg-slate-800/60 focus:border-indigo-500'}"
						/>
						<input
							type="number"
							placeholder="0"
							value={prop.default}
							aria-label={`Property ${i + 1} default value`}
							oninput={(e) => setPropertyDefault(i, (e.currentTarget as HTMLInputElement).value)}
							class="w-full rounded-lg border border-slate-600 bg-slate-800/60 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 transition outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50"
						/>
						<button
							type="button"
							onclick={() => removeProperty(i)}
							aria-label="Remove property"
							class="flex h-9 w-9 items-center justify-center rounded-lg text-slate-500 transition hover:bg-red-500/10 hover:text-red-400"
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
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
								/>
							</svg>
						</button>
					</div>
				{/each}
			</div>
		{:else}
			<p class="py-6 text-center text-sm text-slate-500">
				No properties yet. Add one to define entity stats.
			</p>
		{/if}
	</div>

	<div class="flex items-center justify-between">
		<div class="space-y-1">
			{#if config.zones.length === 0}
				<p class="text-xs text-red-400">At least one zone is required.</p>
			{/if}
			{#if hasEmptyName}
				<p class="text-xs text-red-400">All zones and properties must have a name.</p>
			{/if}
			{#if hasDuplicateZoneName()}
				<p class="text-xs text-red-400">Zone names must be unique.</p>
			{/if}
		</div>
		<button
			type="button"
			onclick={save}
			disabled={!canSave}
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
				Save Configuration
			{/if}
		</button>
	</div>
</div>
