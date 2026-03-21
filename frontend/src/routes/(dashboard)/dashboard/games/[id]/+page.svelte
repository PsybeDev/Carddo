<script lang="ts">
	import { page } from '$app/state';
	import { apiGet } from '$lib/api/client';

	let cardCount = $state<number | null>(null);
	let deckCount = $state<number | null>(null);

	$effect(() => {
		const id = page.params.id;
		void apiGet<unknown[]>(`/api/games/${id}/cards`)
			.then((cards) => {
				cardCount = cards.length;
			})
			.catch(() => {
				cardCount = 0;
			});
		void apiGet<unknown[]>(`/api/games/${id}/decks`)
			.then((decks) => {
				deckCount = decks.length;
			})
			.catch(() => {
				deckCount = 0;
			});
	});
</script>

<svelte:head><title>Game Overview — Carddo</title></svelte:head>

<div class="space-y-6">
	<!-- Stats row -->
	<div class="grid grid-cols-2 gap-4 sm:grid-cols-3">
		<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
			<p class="text-xs font-medium tracking-wide text-slate-500 uppercase">Cards</p>
			<p class="mt-1.5 text-2xl font-semibold text-slate-100">
				{cardCount !== null ? cardCount : '—'}
			</p>
		</div>
		<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
			<p class="text-xs font-medium tracking-wide text-slate-500 uppercase">Decks</p>
			<p class="mt-1.5 text-2xl font-semibold text-slate-100">
				{deckCount !== null ? deckCount : '—'}
			</p>
		</div>
	</div>

	<!-- Playtest CTA -->
	<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-6">
		<h2 class="text-sm font-medium text-slate-200">Playtest your game</h2>
		<p class="mt-1 text-sm text-slate-400">
			Jump into a live session to test your cards and rules.
		</p>
		<a
			href="/dashboard/games/{page.params.id}/playtest"
			class="mt-4 inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
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
					d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z"
				/>
			</svg>
			Start Playtest
		</a>
	</div>
</div>
