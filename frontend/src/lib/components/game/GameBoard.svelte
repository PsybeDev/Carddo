<script lang="ts">
	import type { GameState } from '$lib/types/ditto.generated';
	import Zone from './Zone.svelte';
	import WinnerScreen from './WinnerScreen.svelte';

	let {
		gameState,
		currentPlayerId,
		validDropTargets,
		gameOver,
		onDrop
	}: {
		gameState: GameState;
		currentPlayerId: string;
		validDropTargets: string[];
		gameOver?: { winner_id?: string } | null;
		onDrop: (entityId: string, toZone: string) => void;
	} = $props();

	const zones = $derived(Object.values(gameState.zones));
	const opponentZones = $derived(
		zones.filter((z) => z.owner_id !== null && z.owner_id !== currentPlayerId)
	);
	const neutralZones = $derived(zones.filter((z) => z.owner_id === null));
	const playerZones = $derived(zones.filter((z) => z.owner_id === currentPlayerId));
	const isGameOver = $derived(!!gameOver);
	const isEmpty = $derived(zones.length === 0);
</script>

{#if isEmpty}
	<div
		data-testid="game-board-empty"
		class="flex h-full w-full items-center justify-center text-slate-500"
	>
		<p>Waiting for game to start...</p>
	</div>
{:else}
	<div class="relative h-full w-full">
		<div
			data-testid="game-board"
			class="grid h-full grid-rows-3 gap-4 p-4 {isGameOver ? 'pointer-events-none' : ''}"
		>
			<section data-testid="opponent-zones" class="flex items-start justify-center gap-4">
				{#each opponentZones as zone (zone.id)}
					<Zone
						{zone}
						entities={gameState.entities}
						{currentPlayerId}
						{validDropTargets}
						{onDrop}
					/>
				{/each}
			</section>

			<section data-testid="neutral-zones" class="flex items-center justify-center gap-4">
				{#each neutralZones as zone (zone.id)}
					<Zone
						{zone}
						entities={gameState.entities}
						{currentPlayerId}
						{validDropTargets}
						{onDrop}
					/>
				{/each}
			</section>

			<section data-testid="player-zones" class="flex items-end justify-center gap-4">
				{#each playerZones as zone (zone.id)}
					<Zone
						{zone}
						entities={gameState.entities}
						{currentPlayerId}
						{validDropTargets}
						{onDrop}
					/>
				{/each}
			</section>
		</div>

		{#if isGameOver}
			<WinnerScreen visible={true} winnerId={gameOver?.winner_id} />
		{/if}
	</div>
{/if}
