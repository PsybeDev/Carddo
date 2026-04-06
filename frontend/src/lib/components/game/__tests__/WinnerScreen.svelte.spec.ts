import { page } from 'vitest/browser';
import { describe, expect, it } from 'vitest';
import { render } from 'vitest-browser-svelte';
import WinnerScreen from '../WinnerScreen.svelte';

describe('WinnerScreen', () => {
	it('renders overlay with data-testid="winner-screen" when visible=true', async () => {
		render(WinnerScreen, {
			visible: true,
			winnerId: undefined
		});

		await expect.element(page.getByTestId('winner-screen')).toBeInTheDocument();
	});

	it('shows "Game Over" text when visible=true', async () => {
		render(WinnerScreen, {
			visible: true,
			winnerId: undefined
		});

		await expect.element(page.getByText('Game Over')).toBeInTheDocument();
	});

	it('displays winnerId when provided', async () => {
		render(WinnerScreen, {
			visible: true,
			winnerId: 'Player 1'
		});

		await expect.element(page.getByText('Winner: Player 1')).toBeInTheDocument();
	});

	it('shows "Game Over" without winner text when winnerId is undefined', async () => {
		render(WinnerScreen, {
			visible: true,
			winnerId: undefined
		});

		await expect.element(page.getByText('Game Over')).toBeInTheDocument();
		await expect.element(page.getByText(/^Winner:/)).not.toBeInTheDocument();
	});

	it('does not render when visible=false', async () => {
		render(WinnerScreen, {
			visible: false,
			winnerId: 'Player 1'
		});

		await expect.element(page.getByTestId('winner-screen')).not.toBeInTheDocument();
		await expect.element(page.getByText('Game Over')).not.toBeInTheDocument();
	});
});
