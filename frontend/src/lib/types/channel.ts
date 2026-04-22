/**
 * Phoenix Channel payload types for real-time gameplay.
 *
 * Game engine types (GameState, Action, Entity, Zone) live in
 * ditto.generated.ts — they are imported here, never redefined.
 */

import type { Action } from '$lib/types/ditto.generated';

/** Reactive connection lifecycle state. */
export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'error';

/** Params sent when joining a game channel. */
export type JoinParams = {
	game_id: number;
	deck_id: number;
	solo_mode?: boolean;
};

/**
 * Server response on successful channel join.
 * `state` is a JSON **string** — call `JSON.parse()` to get a `GameState`.
 * `ai_player_id` is set when the room is in solo mode; `active_player_id` is
 * the player whose turn it currently is.
 */
export type JoinResponse = {
	state: string;
	ai_player_id?: string | null;
	active_player_id?: string | null;
};

/** Payload pushed to the server via `"submit_action"`. */
export type ActionPayload = {
	client_sequence_id: number;
	action: Action;
};

/**
 * Server push received via `channel.on("action_rejected", ...)`.
 * This is NOT a reply to the push — it arrives as a separate event.
 */
export type ActionRejectedPayload = {
	client_sequence_id: number;
	errors: ChannelError[];
};

/**
 * Server broadcast received via `channel.on("state_resolved", ...)`.
 * `state` is a JSON **string** — call `JSON.parse()` to get a `GameState`.
 * `active_player_id` is the player whose turn it is after this resolution.
 */
export type StateResolvedPayload = {
	state: string;
	active_player_id?: string | null;
};

/** Individual error matching the CAR-60 error envelope shape. */
export type ChannelError = {
	message: string;
	code: string;
};

/** Error envelope returned for join failures and malformed payload replies. */
export type ChannelErrorEnvelope = {
	errors: ChannelError[];
};

/**
 * Server broadcast received via `channel.on("game_over", ...)`.
 * `final_state` is a JSON **string** — call `JSON.parse()` to get a `GameState`.
 */
export type GameOverPayload = {
	winner_id?: string;
	final_state: string;
};
