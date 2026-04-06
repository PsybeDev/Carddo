<script lang="ts">
	import { Spring } from 'svelte/motion';
	import { flushSync } from 'svelte';
	import type { Entity } from '$lib/types/ditto.generated';
	import type { GameConfig } from '$lib/types/api';

	let {
		entity,
		gameConfig: _gameConfig,
		isOwner,
		disabled = false,
		onDropAttempt
	}: {
		entity: Entity;
		gameConfig?: GameConfig;
		isOwner: boolean;
		disabled?: boolean;
		onDropAttempt: (entityId: string, toZone: string) => void;
	} = $props();

	const pos = new Spring({ x: 0, y: 0 }, { stiffness: 0.2, damping: 0.6 });
	let dragging = $state(false);
	let dragStart = $state({ x: 0, y: 0 });
	let cardElement: HTMLDivElement;
	const isTapped = $derived(entity.properties?.tapped === 1);

	export function snapBack() {
		pos.target = { x: 0, y: 0 };
	}

	function handlePointerDown(e: PointerEvent) {
		if (disabled || !isOwner) return;
		dragStart = { x: e.clientX - pos.current.x, y: e.clientY - pos.current.y };
		flushSync(() => {
			dragging = true;
		});
	}

	$effect(() => {
		if (!dragging) return;

		const handleMove = (e: PointerEvent) => {
			pos.target = { x: e.clientX - dragStart.x, y: e.clientY - dragStart.y };
		};

		const handleUp = (e: PointerEvent) => {
			if (cardElement) {
				cardElement.style.pointerEvents = 'none';
			}
			const el = document.elementFromPoint(e.clientX, e.clientY);
			if (cardElement) {
				cardElement.style.pointerEvents = '';
			}
			const zone = el?.closest('[data-testid^="zone-"]');
			const zoneId = zone?.getAttribute('data-testid')?.replace('zone-', '');
			if (zoneId) onDropAttempt(entity.id, zoneId);
			pos.target = { x: 0, y: 0 };
			dragging = false;
		};

		document.addEventListener('pointermove', handleMove);
		document.addEventListener('pointerup', handleUp);

		return () => {
			document.removeEventListener('pointermove', handleMove);
			document.removeEventListener('pointerup', handleUp);
		};
	});
</script>

<div
	bind:this={cardElement}
	data-testid="card-{entity.id}"
	role="button"
	tabindex="0"
	class="relative h-28 w-20 rounded-lg border border-slate-600 bg-slate-700 select-none {dragging
		? 'dragging z-50 scale-105 cursor-grabbing shadow-lg shadow-black/30'
		: 'cursor-grab'}"
	style="transform: translate({pos.current.x}px, {pos.current.y}px){isTapped
		? ' rotate(90deg)'
		: ''}"
	onpointerdown={handlePointerDown}
>
	<p class="p-2 font-mono text-xs text-slate-300">{entity.template_id}</p>
</div>
