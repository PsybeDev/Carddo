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
};

/**
 * Server response on successful channel join.
 * `state` is a JSON **string** — call `JSON.parse()` to get a `GameState`.
 */
export type JoinResponse = {
	state: string;
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
 */
export type StateResolvedPayload = {
	state: string;
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
