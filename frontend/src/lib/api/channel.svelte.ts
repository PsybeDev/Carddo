import { browser } from '$app/environment';
import type { Channel, Socket } from 'phoenix';
import type { GameState, Action } from '$lib/types/ditto.generated';
import type {
	ConnectionStatus,
	JoinParams,
	JoinResponse,
	ActionRejectedPayload,
	StateResolvedPayload,
	ChannelError
} from '$lib/types/channel';

/**
 * Derive WebSocket URL from an HTTP API URL.
 *
 * http://localhost:4000  → ws://localhost:4000/socket
 * https://example.com    → wss://example.com/socket
 */
export function buildWsUrl(apiUrl: string): string {
	const trimmed = apiUrl.replace(/\/+$/, '');
	return trimmed.replace(/^http/, 'ws') + '/socket';
}

/**
 * Parse a JSON string from the server into a GameState object.
 * Throws a descriptive error if parsing fails.
 */
export function parseGameState(stateJson: string): GameState {
	if (!stateJson) {
		throw new Error('Cannot parse empty state string');
	}
	return JSON.parse(stateJson) as GameState;
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
			this.gameState = parseGameState(payload.state);
		});

		this.channel.on('action_rejected', (payload: ActionRejectedPayload) => {
			this.lastRejection = payload;
		});

		this.channel
			.join()
			.receive('ok', (response: JoinResponse) => {
				this.gameState = parseGameState(response.state);
				this.connectionStatus = 'connected';
			})
			.receive('error', (reason: { errors: ChannelError[] }) => {
				this.errors = reason.errors;
				this.connectionStatus = 'error';
			})
			.receive('timeout', () => {
				this.connectionStatus = 'error';
			});
	}

	submitAction(action: Action): void {
		if (!this.channel) return;

		this.sequenceId += 1;

		this.channel
			.push('submit_action', {
				client_sequence_id: this.sequenceId,
				action
			})
			.receive('error', (reason: { errors: ChannelError[] }) => {
				this.errors = reason.errors;
			})
			.receive('timeout', () => {
				this.errors = [{ message: 'Action timed out', code: 'timeout' }];
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
