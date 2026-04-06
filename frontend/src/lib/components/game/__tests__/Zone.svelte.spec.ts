import { page } from 'vitest/browser';
import { describe, expect, it, vi } from 'vitest';
import { render } from 'vitest-browser-svelte';
import Zone from '../Zone.svelte';
import { mockEntities, mockZones, PLAYER_1_ID, PLAYER_2_ID } from './mock-game-state';
import type { Zone as ZoneType } from '$lib/types/ditto.generated';

describe('Zone', () => {
	// Test 1: Public zone renders entity template_ids
	it('Public zone renders entity template_ids', async () => {
		render(Zone, {
			zone: mockZones.zone_a_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_a_p1')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-entity_a')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-entity_b')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-entity_tapped')).toBeInTheDocument();
		await expect.element(page.getByText('card_template_a')).toBeInTheDocument();
		await expect.element(page.getByText('card_template_b')).toBeInTheDocument();
		await expect.element(page.getByText('card_template_tapped')).toBeInTheDocument();
	});

	// Test 2: OwnerOnly zone — owner sees entities
	it('OwnerOnly zone renders entity details when currentPlayerId matches owner', async () => {
		render(Zone, {
			zone: mockZones.zone_b_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_b_p1')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-entity_c')).toBeInTheDocument();
		await expect.element(page.getByText('card_template_c')).toBeInTheDocument();
	});

	// Test 3: OwnerOnly zone — non-owner sees CardBacks
	it('OwnerOnly zone renders CardBacks for non-owner', async () => {
		render(Zone, {
			zone: mockZones.zone_b_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_2_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_b_p1')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-entity_c')).not.toBeInTheDocument();
		const cardBacks = page.getByTestId('card-back');
		await expect(cardBacks.elements()).toHaveLength(2);
	});

	// Test 4: Hidden zone renders CardBack components for the count
	it('Hidden zone { Hidden: 3 } renders 3 CardBack elements', async () => {
		render(Zone, {
			zone: mockZones.zone_d_hidden,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_d_hidden')).toBeInTheDocument();
		const cardBacks = page.getByTestId('card-back');
		await expect(cardBacks.elements()).toHaveLength(3);
	});

	// Test 5: Hidden zone with count 0 renders empty zone
	it('Hidden zone { Hidden: 0 } renders empty zone', async () => {
		render(Zone, {
			zone: mockZones.zone_e_empty_hidden,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_e_empty_hidden')).toBeInTheDocument();
		const cardBacks = page.getByTestId('card-back');
		await expect(cardBacks.elements()).toHaveLength(0);
	});

	// Test 6: Drop target highlight
	it('highlights with ring when zone.id is in validDropTargets', async () => {
		render(Zone, {
			zone: mockZones.zone_a_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: ['zone_a_p1'],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_a_p1')).toHaveClass('ring-2');
	});

	// Test 7: No highlight when not in validDropTargets
	it('does not highlight when zone.id is NOT in validDropTargets', async () => {
		render(Zone, {
			zone: mockZones.zone_a_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: ['some_other_zone'],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_a_p1')).not.toHaveClass('ring-2');
	});

	// Test 8: Empty Public zone has min-height (doesn't collapse)
	it('empty Public zone renders container with data-testid', async () => {
		render(Zone, {
			zone: mockZones.zone_g_empty,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_g_empty')).toBeInTheDocument();
		await expect.element(page.getByTestId('zone-zone_g_empty')).toHaveClass('min-h-[100px]');
	});

	// Test 9: onDrop callback fires on drop event
	it('calls onDrop with entityId and zone.id when drop fires', async () => {
		const onDropMock = vi.fn();
		render(Zone, {
			zone: mockZones.zone_a_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: ['zone_a_p1'],
			onDrop: onDropMock
		});

		const zoneEl = page.getByTestId('zone-zone_a_p1').element();
		const dropEvent = new Event('drop');
		Object.defineProperty(dropEvent, 'dataTransfer', {
			value: {
				getData: vi.fn().mockReturnValue('entity_x')
			}
		});
		zoneEl.dispatchEvent(dropEvent);

		expect(onDropMock).toHaveBeenCalledWith('entity_x', 'zone_a_p1');
	});

	// Test 10: onDrop does NOT fire on non-target zone
	it('does not call onDrop when zone is not a valid drop target', async () => {
		const onDropMock = vi.fn();
		render(Zone, {
			zone: mockZones.zone_a_p1,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: onDropMock
		});

		const zoneEl = page.getByTestId('zone-zone_a_p1').element();
		const dropEvent = new Event('drop');
		Object.defineProperty(dropEvent, 'dataTransfer', {
			value: {
				getData: vi.fn().mockReturnValue('entity_x')
			}
		});
		zoneEl.dispatchEvent(dropEvent);

		expect(onDropMock).not.toHaveBeenCalled();
	});

	// Test 11: Missing entity IDs are skipped
	it('skips missing entity IDs without crashing', async () => {
		const zoneWithMissingEntity: ZoneType = {
			...mockZones.zone_a_p1,
			entities: ['entity_a', 'missing_entity_id']
		};
		render(Zone, {
			zone: zoneWithMissingEntity,
			entities: mockEntities,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			onDrop: vi.fn()
		});
		await expect.element(page.getByTestId('zone-zone_a_p1')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-entity_a')).toBeInTheDocument();
		await expect.element(page.getByTestId('card-missing_entity_id')).not.toBeInTheDocument();
	});
});
