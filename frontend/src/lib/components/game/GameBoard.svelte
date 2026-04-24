<script lang="ts">
	import type { GameState } from '$lib/types/ditto.generated';
	import Zone from './Zone.svelte';
	import WinnerScreen from './WinnerScreen.svelte';

	let {
		gameState,
		currentPlayerId,
		validDropTargets,
		gameOver,
		aiPlayerId = null,
		activePlayerId = null,
		onDrop,
		onReturnToDashboard
	}: {
		gameState: GameState;
		currentPlayerId: string;
		validDropTargets: string[];
		gameOver?: { winner_id?: string } | null;
		aiPlayerId?: string | null;
		activePlayerId?: string | null;
		onDrop: (entityId: string, toZone: string) => void;
		onReturnToDashboard?: () => void;
	} = $props();

	const zones = $derived(Object.values(gameState.zones));
	const opponentZones = $derived(
		zones.filter((z) => z.owner_id !== null && z.owner_id !== currentPlayerId)
	);
	const neutralZones = $derived(zones.filter((z) => z.owner_id === null));
	const playerZones = $derived(zones.filter((z) => z.owner_id === currentPlayerId));
	const isGameOver = $derived(!!gameOver);
	const isEmpty = $derived(zones.length === 0);
	const isAiTurn = $derived(aiPlayerId !== null && activePlayerId === aiPlayerId);
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
			<section data-testid="opponent-zones" class="flex flex-col items-center justify-start gap-2">
				{#if aiPlayerId}
					<div
						data-testid="ai-label"
						class="flex items-center gap-2 text-xs font-medium text-slate-400"
					>
						<span>AI</span>
						{#if isAiTurn}
							<span
								data-testid="ai-thinking"
								class="inline-flex items-center gap-1 text-indigo-400 italic"
							>
								<span class="inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-indigo-400"
								></span>
								thinking…
							</span>
						{/if}
					</div>
				{/if}
				<div class="flex items-start justify-center gap-4">
					{#each opponentZones as zone (zone.id)}
						<Zone
							{zone}
							entities={gameState.entities}
							{currentPlayerId}
							{validDropTargets}
							{onDrop}
						/>
					{/each}
				</div>
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
			<WinnerScreen visible={true} winnerId={gameOver?.winner_id} {onReturnToDashboard} />
		{/if}
	</div>
{/if}
