<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { ApiError, apiGet, apiPatch } from '$lib/api/client';
	import { toastStore } from '$lib/stores/toast.svelte';
	import type { Game } from '$lib/types/api';
	import { setContext } from 'svelte';

	let { children } = $props();

	let game = $state<Game | null>(null);
	let titleInput = $state('');
	let saving = $state(false);
	let loadError = $state(false);

	setContext('game', () => game);

	$effect(() => {
		if (page.params.id) void loadGame(page.params.id);
	});

	async function loadGame(id: string) {
		loadError = false;
		game = null;
		titleInput = '';
		try {
			const loaded = await apiGet<Game>(`/api/games/${id}`);
			if (page.params.id !== id) return;
			game = loaded;
			titleInput = loaded.title;
		} catch (err) {
			if (page.params.id !== id) return;
			if (err instanceof ApiError && (err.status === 403 || err.status === 404)) {
				toastStore.show('Game not found or you do not have access.');
				goto('/dashboard');
			} else {
				loadError = true;
			}
		}
	}

	async function handleTitleBlur() {
		if (!game) return;
		const trimmed = titleInput.trim();
		if (!trimmed) {
			titleInput = game.title;
			return;
		}
		if (trimmed === game.title) return;

		const gameId = game.id;
		saving = true;
		try {
			const updated = await apiPatch<Game>(`/api/games/${gameId}`, { title: trimmed });
			if (page.params.id !== String(gameId)) return;
			game = updated;
			titleInput = updated.title;
		} catch {
			if (page.params.id !== String(gameId)) return;
			titleInput = game?.title ?? '';
		} finally {
			saving = false;
		}
	}

	const navItems = [
		{ label: 'Overview', href: '' },
		{ label: 'Configure', href: '/config' },
		{ label: 'Cards', href: '/cards' },
		{ label: 'Decks', href: '/decks' },
		{ label: 'Playtest', href: '/playtest' }
	] as const;

	function navHref(suffix: string) {
		return `/dashboard/games/${page.params.id}${suffix}`;
	}

	function isActive(suffix: string) {
		const target = navHref(suffix);
		return suffix === '' ? page.url.pathname === target : page.url.pathname.startsWith(target);
	}
</script>

{#if loadError}
	<div class="flex flex-col items-center justify-center py-24 text-center">
		<p class="text-sm text-slate-400">Failed to load game.</p>
		<button
			type="button"
			onclick={() => {
				if (page.params.id) void loadGame(page.params.id);
			}}
			class="mt-3 text-sm text-indigo-400 transition hover:text-indigo-300"
		>
			Try again
		</button>
	</div>
{:else if game}
	<div>
		<!-- Game workspace header -->
		<div class="mb-6 flex items-center gap-3">
			<a
				href="/dashboard"
				class="text-slate-500 transition hover:text-slate-300"
				aria-label="Back to dashboard"
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
					<path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
				</svg>
			</a>
			<div class="flex items-center gap-2">
				<input
					type="text"
					bind:value={titleInput}
					onblur={handleTitleBlur}
					onkeydown={(e) => {
						if (e.key === 'Enter') (e.currentTarget as HTMLInputElement).blur();
						if (e.key === 'Escape') {
							titleInput = game?.title ?? '';
							(e.currentTarget as HTMLInputElement).blur();
						}
					}}
					class="rounded-md border border-transparent bg-transparent px-2 py-1 text-base font-semibold text-slate-100 transition outline-none hover:border-slate-600 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 disabled:opacity-60"
					disabled={saving}
					aria-label="Game title"
				/>
				{#if saving}
					<svg
						class="h-3.5 w-3.5 animate-spin text-slate-500"
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
				{/if}
			</div>
		</div>

		<!-- Side nav + content -->
		<div class="flex gap-8">
			<nav class="w-40 shrink-0">
				<ul class="flex flex-col gap-0.5">
					{#each navItems as item (item.href)}
						<li>
							<a
								href={navHref(item.href)}
								class="block rounded-lg px-3 py-2 text-sm transition
									{isActive(item.href)
									? 'bg-indigo-600/15 font-medium text-indigo-300'
									: 'text-slate-400 hover:bg-slate-700/40 hover:text-slate-200'}"
							>
								{item.label}
							</a>
						</li>
					{/each}
				</ul>
			</nav>

			<div class="min-w-0 flex-1">
				{@render children()}
			</div>
		</div>
	</div>
{:else}
	<!-- Loading skeleton -->
	<div class="animate-pulse">
		<div class="mb-6 h-7 w-48 rounded-md bg-slate-800"></div>
		<div class="flex gap-8">
			<div class="w-40 shrink-0 space-y-1">
				{#each [1, 2, 3, 4, 5] as i (i)}
					<div class="h-9 rounded-lg bg-slate-800"></div>
				{/each}
			</div>
			<div class="flex-1 space-y-3">
				<div class="h-24 rounded-xl bg-slate-800"></div>
				<div class="h-24 rounded-xl bg-slate-800"></div>
			</div>
		</div>
	</div>
{/if}
