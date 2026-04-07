import { page } from 'vitest/browser';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { render } from 'vitest-browser-svelte';
import Card from '../Card.svelte';
import { mockEntities, PLAYER_1_ID } from './mock-game-state';

describe('Card', () => {
	afterEach(() => {
		vi.restoreAllMocks();
	});
	it('renders entity placeholder with data-testid and template_id text', async () => {
		const entity = mockEntities.entity_a;
		render(Card, {
			entity,
			isDraggable: true,
			disabled: false,
			onDropAttempt: vi.fn()
		});
		await expect.element(page.getByTestId('card-entity_a')).toBeInTheDocument();
		await expect.element(page.getByText(entity.template_id)).toBeInTheDocument();
	});

	it('isDraggable false — card renders but drag does not fire onDropAttempt', async () => {
		const onDropAttempt = vi.fn();
		render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: false,
			disabled: false,
			onDropAttempt
		});

		const cardEl = page.getByTestId('card-entity_a').element();
		cardEl.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));

		expect(onDropAttempt).not.toHaveBeenCalled();
		expect(cardEl.classList.contains('dragging')).toBe(false);
	});

	it('disabled true — pointerdown does not start dragging', async () => {
		render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: true,
			disabled: true,
			onDropAttempt: vi.fn()
		});

		const cardEl = page.getByTestId('card-entity_a').element();
		cardEl.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));

		expect(cardEl.classList.contains('dragging')).toBe(false);
	});

	it('tapped entity (properties.tapped === 1) applies rotate(90deg) via CSS variable', async () => {
		render(Card, {
			entity: mockEntities.entity_tapped,
			isDraggable: true,
			disabled: false,
			onDropAttempt: vi.fn()
		});

		const cardEl = page.getByTestId('card-entity_tapped').element();
		await expect.element(page.getByTestId('card-entity_tapped')).toBeInTheDocument();
		expect(cardEl.getAttribute('style') ?? '').toContain('--tw-rotate: 90deg');
	});

	it('non-tapped entity does not have 90deg rotation', async () => {
		render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: true,
			disabled: false,
			onDropAttempt: vi.fn()
		});

		const cardEl = page.getByTestId('card-entity_a').element();
		expect(cardEl.getAttribute('style') ?? '').not.toContain('--tw-rotate: 90deg');
	});

	it('snapBack() can be called on the component instance without error', async () => {
		const { component } = render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: true,
			disabled: false,
			onDropAttempt: vi.fn()
		});

		expect(() => (component as unknown as { snapBack: () => void }).snapBack()).not.toThrow();
	});

	it('drag lifecycle calls onDropAttempt(entityId, zoneId) when dropped on a valid zone', async () => {
		const onDropAttempt = vi.fn();
		render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: true,
			disabled: false,
			validDropTargets: ['target_zone', 'other_zone'],
			onDropAttempt
		});

		const fakeZoneEl = document.createElement('div');
		fakeZoneEl.setAttribute('data-zone-id', 'target_zone');
		vi.spyOn(document, 'elementFromPoint').mockReturnValue(fakeZoneEl);

		const cardEl = page.getByTestId('card-entity_a').element();
		cardEl.dispatchEvent(
			new PointerEvent('pointerdown', { bubbles: true, clientX: 100, clientY: 100 })
		);
		document.dispatchEvent(
			new PointerEvent('pointermove', { bubbles: true, clientX: 150, clientY: 150 })
		);
		document.dispatchEvent(
			new PointerEvent('pointerup', { bubbles: true, clientX: 150, clientY: 150 })
		);

		expect(onDropAttempt).toHaveBeenCalledWith('entity_a', 'target_zone');
	});

	it('drop on non-zone does NOT call onDropAttempt', async () => {
		const onDropAttempt = vi.fn();
		render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: true,
			disabled: false,
			validDropTargets: ['target_zone'],
			onDropAttempt
		});

		vi.spyOn(document, 'elementFromPoint').mockReturnValue(null);

		const cardEl = page.getByTestId('card-entity_a').element();
		cardEl.dispatchEvent(
			new PointerEvent('pointerdown', { bubbles: true, clientX: 100, clientY: 100 })
		);
		document.dispatchEvent(
			new PointerEvent('pointermove', { bubbles: true, clientX: 200, clientY: 200 })
		);
		document.dispatchEvent(
			new PointerEvent('pointerup', { bubbles: true, clientX: 200, clientY: 200 })
		);

		expect(onDropAttempt).not.toHaveBeenCalled();
	});

	it('drop on invalid zone (not in validDropTargets) does NOT call onDropAttempt', async () => {
		const onDropAttempt = vi.fn();
		render(Card, {
			entity: mockEntities.entity_a,
			isDraggable: true,
			disabled: false,
			validDropTargets: ['allowed_zone'],
			onDropAttempt
		});

		const fakeZoneEl = document.createElement('div');
		fakeZoneEl.setAttribute('data-zone-id', 'forbidden_zone');
		vi.spyOn(document, 'elementFromPoint').mockReturnValue(fakeZoneEl);

		const cardEl = page.getByTestId('card-entity_a').element();
		cardEl.dispatchEvent(
			new PointerEvent('pointerdown', { bubbles: true, clientX: 100, clientY: 100 })
		);
		document.dispatchEvent(
			new PointerEvent('pointermove', { bubbles: true, clientX: 200, clientY: 200 })
		);
		document.dispatchEvent(
			new PointerEvent('pointerup', { bubbles: true, clientX: 200, clientY: 200 })
		);

		expect(onDropAttempt).not.toHaveBeenCalled();
	});

	it('renders template_id only — does not render property keys or values', async () => {
		const entity = {
			id: 'entity_props_test',
			owner_id: PLAYER_1_ID,
			template_id: 'card_template_props_test',
			properties: { str: 5, def: 3 },
			abilities: [] as never[]
		};
		render(Card, {
			entity,
			isDraggable: true,
			disabled: false,
			onDropAttempt: vi.fn()
		});

		await expect.element(page.getByTestId('card-entity_props_test')).toBeInTheDocument();
		await expect.element(page.getByText(entity.template_id)).toBeInTheDocument();
		await expect.element(page.getByText('str')).not.toBeInTheDocument();
		await expect.element(page.getByText('def')).not.toBeInTheDocument();
		await expect.element(page.getByText('5')).not.toBeInTheDocument();
		await expect.element(page.getByText('3')).not.toBeInTheDocument();
	});
});
