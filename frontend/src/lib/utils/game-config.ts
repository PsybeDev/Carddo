import { normalizeRule } from '$lib/components/builder/utils';
import type { Game, GameConfig, PropertyConfig, ZoneConfig } from '$lib/types/api';

export function normalizeZones(value: unknown): ZoneConfig[] {
	if (!Array.isArray(value)) return [];
	return value.map((z) => {
		const obj = z && typeof z === 'object' ? (z as Record<string, unknown>) : {};
		const vis = typeof obj.visibility === 'string' ? obj.visibility : 'Public';
		const visibility = (
			vis === 'Public' || vis === 'OwnerOnly' || vis === 'Hidden' ? vis : 'Public'
		) as ZoneConfig['visibility'];
		const capacityRaw = obj.capacity;
		const capacity =
			typeof capacityRaw === 'number' && Number.isFinite(capacityRaw) ? capacityRaw : null;
		return { name: typeof obj.name === 'string' ? obj.name : '', visibility, capacity };
	});
}

export function normalizeProperties(value: unknown): PropertyConfig[] {
	if (!Array.isArray(value)) return [];
	return value.map((p) => {
		const obj = p && typeof p === 'object' ? (p as Record<string, unknown>) : {};
		const defaultRaw = obj.default;
		return {
			name: typeof obj.name === 'string' ? obj.name : '',
			default: typeof defaultRaw === 'number' && Number.isFinite(defaultRaw) ? defaultRaw : 0
		};
	});
}

export function normalizeConfig(raw: Game['config'] | undefined): GameConfig {
	if (!raw) return { zones: [], properties: [], rules: [], win_conditions: [] };
	return {
		zones: normalizeZones(raw.zones),
		properties: normalizeProperties(raw.properties),
		rules: Array.isArray(raw.rules) ? raw.rules.map(normalizeRule) : [],
		win_conditions: Array.isArray(raw.win_conditions) ? raw.win_conditions.map(normalizeRule) : []
	};
}
