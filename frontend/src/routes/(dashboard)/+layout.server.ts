import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = ({ locals }) => {
	if (!locals.token) {
		throw redirect(302, '/login');
	}
	return { isAuthenticated: true };
};
