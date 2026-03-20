import { PUBLIC_API_URL } from '$env/static/public';

export class ApiError extends Error {
	constructor(
		public readonly messages: string[],
		public readonly status: number
	) {
		super(messages[0] ?? 'Request failed');
		this.name = 'ApiError';
	}
}

export type AuthTokenGetter = () => string | null;

let _getToken: AuthTokenGetter = () => null;

export function setTokenGetter(fn: AuthTokenGetter): void {
	_getToken = fn;
}

type ErrorEnvelope = { errors?: Array<{ message: string }> };

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
	const token = _getToken();
	const headers: Record<string, string> = { 'Content-Type': 'application/json' };
	if (token) headers['Authorization'] = `Bearer ${token}`;

	const res = await fetch(`${PUBLIC_API_URL}${path}`, {
		method,
		headers,
		body: body !== undefined ? JSON.stringify(body) : undefined
	});

	if (res.status === 204 || res.status === 205) {
		return undefined as unknown as T;
	}

	let json: unknown;
	try {
		json = await res.json();
	} catch {
		if (!res.ok) {
			let text: string | null = null;
			try {
				text = await res.text();
			} catch {
				// ignore secondary failure
			}
			throw new ApiError(text ? [text] : [res.statusText], res.status);
		}
		throw new ApiError(['Failed to parse response'], res.status);
	}

	if (!res.ok) {
		const errs = (json as ErrorEnvelope)?.errors;
		const messages = errs?.map((e) => e.message) ?? [res.statusText];
		throw new ApiError(messages, res.status);
	}

	return (json as { data: T }).data;
}

export function apiGet<T>(path: string): Promise<T> {
	return request<T>('GET', path);
}

export function apiPost<T>(path: string, body: unknown): Promise<T> {
	return request<T>('POST', path, body);
}
