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

function buildUrl(path: string): string {
	if (!PUBLIC_API_URL) throw new Error('PUBLIC_API_URL is not configured');
	return new URL(path, PUBLIC_API_URL).toString();
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
	const token = _getToken();
	const headers: Record<string, string> = { Accept: 'application/json' };
	if (token) headers['Authorization'] = `Bearer ${token}`;
	if (body !== undefined) headers['Content-Type'] = 'application/json';

	const res = await fetch(buildUrl(path), {
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

export function apiPatch<T>(path: string, body: unknown): Promise<T> {
	return request<T>('PATCH', path, body);
}

export function apiDelete<T>(path: string): Promise<T> {
	return request<T>('DELETE', path);
}
