import { browser } from '$app/environment';
import type { Channel, Socket } from 'phoenix';
import type { GameState, Action } from '$lib/types/ditto.generated';
import type {
	ConnectionStatus,
	JoinParams,
	JoinResponse,
	ActionRejectedPayload,
	StateResolvedPayload,
	ChannelError,
	ChannelErrorEnvelope,
	GameOverPayload
} from '$lib/types/channel';
import { gameStore } from '$lib/stores/game.svelte';

/**
 * Derive WebSocket URL from an HTTP API URL.
 *
 * http://localhost:4000      → ws://localhost:4000/socket
 * https://example.com        → wss://example.com/socket
 * https://example.com/api    → wss://example.com/socket
 */
export function buildWsUrl(apiUrl: string): string {
	if (!apiUrl.trim()) {
		throw new Error('PUBLIC_API_URL is missing or empty; cannot derive WebSocket URL');
	}

	let url: URL;
	try {
		// eslint-disable-next-line svelte/prefer-svelte-reactivity -- pure utility, not reactive context
		url = new URL(apiUrl);
	} catch (err) {
		const msg = err instanceof Error ? err.message : 'unknown error';
		throw new Error(`PUBLIC_API_URL is invalid; cannot derive WebSocket URL: ${msg}`);
	}

	const wsProtocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
	return `${wsProtocol}//${url.host}/socket`;
}

/**
 * Parse a JSON string from the server into a GameState object.
 * Throws a descriptive error if parsing fails.
 */
export function parseGameState(stateJson: string): GameState {
	if (!stateJson) {
		throw new Error('Cannot parse empty state string');
	}
	try {
		return JSON.parse(stateJson) as GameState;
	} catch (err) {
		const msg = err instanceof Error ? err.message : 'unknown error';
		throw new Error(`Failed to parse game state: ${msg}`);
	}
}

/**
 * Reactive Phoenix Channel client for game sessions.
 *
 * Uses Svelte 5 `$state` runes for reactive connection status and game state.
 * Phoenix Socket is dynamically imported inside `connect()` for SSR safety.
 */
export class GameChannel {
	connectionStatus = $state<ConnectionStatus>('disconnected');
	gameState = $state<GameState | null>(null);
	lastRejection = $state<ActionRejectedPayload | null>(null);
	errors = $state<ChannelError[]>([]);

	private socket: Socket | null = null;
	private channel: Channel | null = null;
	private sequenceId = 0;

	constructor(
		private token: string,
		private wsUrl: string
	) {}

	async connect(roomId: string, params: JoinParams): Promise<void> {
		if (!browser) return;

		this.connectionStatus = 'connecting';

		const { Socket: PhoenixSocket } = await import('phoenix');

		this.socket = new PhoenixSocket(this.wsUrl, {
			params: () => ({ token: this.token })
		});
		this.socket.connect();

		this.channel = this.socket.channel('room:' + roomId, params);

		this.channel.on('state_resolved', (payload: StateResolvedPayload) => {
			try {
				this.gameState = parseGameState(payload.state);
				this.lastRejection = null;
			} catch (err) {
				const msg = err instanceof Error ? err.message : 'Failed to parse game state';
				this.errors = [{ message: msg, code: 'parse_error' }];
				this.connectionStatus = 'error';
			}
		});

		this.channel.on('action_rejected', (payload: ActionRejectedPayload) => {
			this.lastRejection = payload;
		});

		this.channel.on('game_over', (payload: GameOverPayload) => {
			gameStore.receiveGameOver(payload);
		});

		await new Promise<void>((resolve, reject) => {
			this.channel!.join()
				.receive('ok', (response: JoinResponse) => {
					try {
						this.gameState = parseGameState(response.state);
						this.connectionStatus = 'connected';
						resolve();
					} catch (error) {
						const parseError =
							error instanceof Error ? error : new Error('Failed to parse game state');
						this.errors = [{ message: parseError.message, code: 'parse_error' }];
						this.connectionStatus = 'error';
						this.channel?.leave();
						this.socket?.disconnect();
						this.channel = null;
						this.socket = null;
						reject(parseError);
					}
				})
				.receive('error', (reason: ChannelErrorEnvelope) => {
					this.errors = reason.errors;
					this.connectionStatus = 'error';
					this.channel?.leave();
					this.socket?.disconnect();
					this.channel = null;
					this.socket = null;
					reject(new Error('Failed to join channel'));
				})
				.receive('timeout', () => {
					this.errors = [{ message: 'Channel join timed out', code: 'timeout' }];
					this.connectionStatus = 'error';
					this.channel?.leave();
					this.socket?.disconnect();
					this.channel = null;
					this.socket = null;
					reject(new Error('Channel join timed out'));
				});
		});
	}

	submitAction(action: Action): void {
		if (!this.channel) return;

		this.lastRejection = null;
		this.sequenceId += 1;

		// Backend returns {:noreply, socket} for valid payloads — no phx_reply
		// is sent. Outcomes arrive via 'state_resolved' and 'action_rejected'
		// events which are already handled in connect().
		this.channel.push('submit_action', {
			client_sequence_id: this.sequenceId,
			action
		});
	}

	disconnect(): void {
		this.channel?.leave();
		this.socket?.disconnect();
		this.connectionStatus = 'disconnected';
		this.gameState = null;
		this.lastRejection = null;
		this.errors = [];
		this.channel = null;
		this.socket = null;
	}

	get currentSequenceId(): number {
		return this.sequenceId;
	}
}
