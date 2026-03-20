import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { ApiError, apiGet, apiPost, setTokenGetter } from '$lib/api/client';

const COOKIE_NAME = 'carddo_token';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30;

export type User = {
	id: string;
	email: string;
	subscription_tier: string;
};

type AuthResponse = {
	token: string;
	user: User;
};

let currentUser = $state<User | null>(null);
let token = $state<string | null>(null);

function secureAttr(): string {
	return browser && window.location.protocol === 'https:' ? '; Secure' : '';
}

function readCookie(): string | null {
	if (!browser) return null;
	const match = document.cookie.match(new RegExp(`(?:^|; )${COOKIE_NAME}=([^;]*)`));
	return match ? decodeURIComponent(match[1]) : null;
}

function writeCookie(value: string): void {
	document.cookie = `${COOKIE_NAME}=${encodeURIComponent(value)}; path=/; max-age=${COOKIE_MAX_AGE}; SameSite=Lax${secureAttr()}`;
}

function clearCookie(): void {
	document.cookie = `${COOKIE_NAME}=; path=/; max-age=0; SameSite=Lax${secureAttr()}`;
}

export const authStore = {
	get currentUser(): User | null {
		return currentUser;
	},
	get token(): string | null {
		return token;
	},

	async init(): Promise<void> {
		const stored = readCookie();
		if (!stored) return;
		token = stored;
		try {
			currentUser = await apiGet<User>('/api/users/me');
		} catch (err) {
			if (err instanceof ApiError && err.status === 401) {
				token = null;
				currentUser = null;
				clearCookie();
				goto('/login');
			}
		}
	},

	async login(email: string, password: string): Promise<void> {
		const data = await apiPost<AuthResponse>('/api/users/login', { email, password });
		token = data.token;
		currentUser = data.user;
		writeCookie(data.token);
	},

	async register(email: string, password: string): Promise<void> {
		const data = await apiPost<AuthResponse>('/api/users/register', { email, password });
		token = data.token;
		currentUser = data.user;
		writeCookie(data.token);
	},

	logout(): void {
		token = null;
		currentUser = null;
		clearCookie();
	}
};

setTokenGetter(() => token);
