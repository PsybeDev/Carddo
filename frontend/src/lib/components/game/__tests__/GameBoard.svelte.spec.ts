import { page } from 'vitest/browser';
import { describe, expect, it, vi } from 'vitest';
import { render } from 'vitest-browser-svelte';
import GameBoard from '../GameBoard.svelte';
import { mockGameState, PLAYER_1_ID, createMockGameState } from './mock-game-state';
import type { GameState } from '$lib/types/ditto.generated';

describe('GameBoard', () => {
	it('Renders correct number of Zone components', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('game-board')).toBeInTheDocument();

		const zoneIds = Object.keys(mockGameState.zones);
		for (const id of zoneIds) {
			await expect.element(page.getByTestId(`zone-${id}`)).toBeInTheDocument();
		}
	});

	it('Groups zones correctly into opponent, neutral, and player sections', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			onDrop: vi.fn()
		});

		const opponentSection = page.getByTestId('opponent-zones');
		const neutralSection = page.getByTestId('neutral-zones');
		const playerSection = page.getByTestId('player-zones');

		await expect.element(opponentSection).toBeInTheDocument();
		await expect.element(neutralSection).toBeInTheDocument();
		await expect.element(playerSection).toBeInTheDocument();

		await expect.element(opponentSection.getByTestId('zone-zone_c_p2')).toBeInTheDocument();
		await expect.element(opponentSection.getByTestId('zone-zone_g_empty')).toBeInTheDocument();

		await expect.element(neutralSection.getByTestId('zone-zone_f_neutral')).toBeInTheDocument();

		await expect.element(playerSection.getByTestId('zone-zone_a_p1')).toBeInTheDocument();
		await expect.element(playerSection.getByTestId('zone-zone_b_p1')).toBeInTheDocument();
	});

	it('Renders empty board indicator when no zones exist', async () => {
		const emptyState: GameState = {
			...mockGameState,
			zones: {}
		};
		render(GameBoard, {
			gameState: emptyState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('game-board-empty')).toBeInTheDocument();
		await expect.element(page.getByTestId('game-board')).not.toBeInTheDocument();
	});

	it('Shows WinnerScreen when gameOver is set', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: { winner_id: PLAYER_1_ID },
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('winner-screen')).toBeInTheDocument();
		await expect.element(page.getByText(`Winner: ${PLAYER_1_ID}`)).toBeInTheDocument();
	});

	it('Does not show WinnerScreen when gameOver is null', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('winner-screen')).not.toBeInTheDocument();
	});

	it('Adds pointer-events-none class to board when gameOver is set', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: { winner_id: PLAYER_1_ID },
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('game-board')).toHaveClass('pointer-events-none');
	});

	it('Passes onDrop callback to Zone components', async () => {
		const onDropMock = vi.fn();
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: ['zone_a_p1'],
			gameOver: null,
			onDrop: onDropMock
		});

		const zoneEl = page.getByTestId('zone-zone_a_p1').element();
		const dropEvent = new Event('drop');
		Object.defineProperty(dropEvent, 'dataTransfer', {
			value: {
				getData: vi.fn().mockReturnValue('entity_a')
			}
		});
		zoneEl.dispatchEvent(dropEvent);

		expect(onDropMock).toHaveBeenCalledWith('entity_a', 'zone_a_p1');
	});

	it('Shows AI label above opponent zones when aiPlayerId is set', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			aiPlayerId: 'p2',
			activePlayerId: PLAYER_1_ID,
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('ai-label')).toBeInTheDocument();
		await expect.element(page.getByTestId('ai-thinking')).not.toBeInTheDocument();
	});

	it('Shows AI thinking indicator when active_player is the AI', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			aiPlayerId: 'p2',
			activePlayerId: 'p2',
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('ai-label')).toBeInTheDocument();
		await expect.element(page.getByTestId('ai-thinking')).toBeInTheDocument();
	});

	it('Hides AI label when aiPlayerId is null', async () => {
		render(GameBoard, {
			gameState: mockGameState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			aiPlayerId: null,
			activePlayerId: null,
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('ai-label')).not.toBeInTheDocument();
	});

	it('Renders dynamically added zones', async () => {
		const newState = createMockGameState({
			zones: {
				...mockGameState.zones,
				new_zone: {
					id: 'new_zone',
					owner_id: PLAYER_1_ID,
					visibility: 'Public',
					entities: []
				}
			}
		});

		render(GameBoard, {
			gameState: newState,
			currentPlayerId: PLAYER_1_ID,
			validDropTargets: [],
			gameOver: null,
			onDrop: vi.fn()
		});

		await expect.element(page.getByTestId('zone-new_zone')).toBeInTheDocument();
	});
});
