<script lang="ts">
	import { Spring } from 'svelte/motion';
	import { flushSync } from 'svelte';
	import type { Entity } from '$lib/types/ditto.generated';

	let {
		entity,
		isDraggable,
		disabled = false,
		validDropTargets = [],
		onDropAttempt
	}: {
		entity: Entity;
		isDraggable: boolean;
		disabled?: boolean;
		validDropTargets?: string[];
		onDropAttempt: (entityId: string, toZone: string) => void;
	} = $props();

	const pos = new Spring({ x: 0, y: 0 }, { stiffness: 0.2, damping: 0.6 });
	let dragging = $state(false);
	let dragStart = $state({ x: 0, y: 0 });
	let activePointerId = $state<number | null>(null);
	let cardElement: HTMLDivElement;
	const isTapped = $derived(entity.properties?.tapped === 1);

	export function snapBack() {
		pos.target = { x: 0, y: 0 };
	}

	function handlePointerDown(e: PointerEvent) {
		if (disabled || !isDraggable || e.button !== 0 || dragging || activePointerId !== null) return;
		activePointerId = e.pointerId;
		dragStart = { x: e.clientX - pos.current.x, y: e.clientY - pos.current.y };
		flushSync(() => {
			dragging = true;
		});
	}

	$effect(() => {
		if (!dragging) return;

		const handleMove = (e: PointerEvent) => {
			if (e.pointerId !== activePointerId) return;
			pos.target = { x: e.clientX - dragStart.x, y: e.clientY - dragStart.y };
		};

		const handleUp = (e: PointerEvent) => {
			if (e.pointerId !== activePointerId) return;
			if (cardElement) {
				cardElement.style.pointerEvents = 'none';
			}
			const el = document.elementFromPoint(e.clientX, e.clientY);
			if (cardElement) {
				cardElement.style.pointerEvents = '';
			}
			const zone = el?.closest('[data-testid^="zone-"]');
			const zoneId = zone?.getAttribute('data-testid')?.replace('zone-', '');

			// Always reset state before calling callback to ensure cleanup runs even if onDropAttempt throws
			pos.target = { x: 0, y: 0 };
			dragging = false;
			activePointerId = null;

			// Only invoke callback if not disabled and zone is valid
			if (!disabled && zoneId && validDropTargets.includes(zoneId)) {
				onDropAttempt(entity.id, zoneId);
			}
		};

		const handleCancel = (e: PointerEvent) => {
			if (e.pointerId !== activePointerId) return;
			pos.target = { x: 0, y: 0 };
			dragging = false;
			activePointerId = null;
		};

		document.addEventListener('pointermove', handleMove);
		document.addEventListener('pointerup', handleUp);
		document.addEventListener('pointercancel', handleCancel);

		return () => {
			document.removeEventListener('pointermove', handleMove);
			document.removeEventListener('pointerup', handleUp);
			document.removeEventListener('pointercancel', handleCancel);
		};
	});
</script>

<div
	bind:this={cardElement}
	data-testid="card-{entity.id}"
	class="relative h-28 w-20 transform touch-none rounded-lg border border-slate-600 bg-slate-700 select-none {dragging
		? 'dragging z-50 scale-105 cursor-grabbing shadow-lg shadow-black/30'
		: disabled
			? 'cursor-not-allowed'
			: isDraggable
				? 'cursor-grab'
				: 'cursor-default'}"
	style="--tw-translate-x: {pos.current.x}px; --tw-translate-y: {pos.current
		.y}px; --tw-rotate: {isTapped ? '90deg' : '0deg'};"
	onpointerdown={handlePointerDown}
>
	<p class="p-2 font-mono text-xs text-slate-300">{entity.template_id}</p>
</div>
