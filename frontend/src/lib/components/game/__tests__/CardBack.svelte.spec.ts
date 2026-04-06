import { page } from 'vitest/browser';
import { describe, expect, it } from 'vitest';
import { render } from 'vitest-browser-svelte';
import CardBack from '../CardBack.svelte';

describe('CardBack', () => {
	it('renders with data-testid="card-back"', async () => {
		render(CardBack, {});

		await expect.element(page.getByTestId('card-back')).toBeInTheDocument();
	});

	it('has aria-label="Hidden card"', async () => {
		render(CardBack, {});

		await expect.element(page.getByLabelText('Hidden card')).toBeInTheDocument();
	});

	it('does not render a count badge when count is undefined', async () => {
		render(CardBack, {});

		const countBadge = page.locator('[class*="bg-slate-700"]');
		await expect.element(countBadge.first()).not.toBeInTheDocument();
	});

	it('renders count badge when count > 1', async () => {
		render(CardBack, { count: 5 });

		await expect.element(page.getByText('5')).toBeInTheDocument();
	});

	it('does not render count badge when count is 1', async () => {
		render(CardBack, { count: 1 });

		const countBadge = page.locator('[class*="bg-slate-700"]');
		await expect.element(page.getByText('1')).not.toBeInTheDocument();
	});
});
