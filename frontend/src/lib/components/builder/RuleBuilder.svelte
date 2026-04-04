<script lang="ts">
	import type { EcaRule, GameConfig } from '$lib/types/api';
	import RuleBlock from './RuleBlock.svelte';
	import { createEmptyRule } from './utils';
	import { getRuleErrors } from '$lib/utils/schema-validator';

	let {
		gameConfig,
		rules = $bindable(),
		onchange,
		title = 'Engine Rules',
		description = 'Define game mechanics using Event-Condition-Action (ECA) triggers.'
	}: {
		gameConfig: GameConfig;
		rules: EcaRule[];
		onchange?: (rules: EcaRule[]) => void;
		title?: string;
		description?: string;
	} = $props();

	let previewOpen = $state(false);
	let copied = $state(false);
	let copyError = $state(false);
	let copyTimeout: ReturnType<typeof setTimeout> | null = null;

	let ruleErrors = $derived(getRuleErrors(rules));
	let hasErrors = $derived(ruleErrors.size > 0);

	let jsonPreview = $derived(
		JSON.stringify(
			rules.map((r) => ({
				id: r.id,
				name: r.name,
				trigger: r.trigger,
				conditions: r.conditions,
				actions: r.actions,
				cancels: r.cancels
			})),
			null,
			2
		)
	);

	function addRule() {
		rules = [...rules, createEmptyRule()];
	}

	function removeRule(i: number) {
		rules = rules.filter((_, idx) => idx !== i);
	}

	$effect(() => {
		onchange?.(rules);
	});

	$effect(() => {
		return () => {
			if (copyTimeout) clearTimeout(copyTimeout);
		};
	});

	async function copyJson() {
		if (copyTimeout) clearTimeout(copyTimeout);
		try {
			await navigator.clipboard.writeText(jsonPreview);
			copied = true;
			copyError = false;
		} catch {
			try {
				const textarea = document.createElement('textarea');
				textarea.value = jsonPreview;
				textarea.style.position = 'fixed';
				textarea.style.opacity = '0';
				document.body.appendChild(textarea);
				textarea.select();
				const ok = document.execCommand('copy');
				document.body.removeChild(textarea);
				if (ok) {
					copied = true;
					copyError = false;
				} else {
					copied = false;
					copyError = true;
				}
			} catch {
				copied = false;
				copyError = true;
			}
		}
		copyTimeout = setTimeout(() => {
			copied = false;
			copyError = false;
		}, 2000);
	}
</script>

<div class="space-y-4">
	<div class="rounded-xl border border-slate-700/50 bg-[#1a1d27] p-5">
		<div class="mb-4 flex items-center justify-between">
			<div class="flex items-center gap-3">
				<div>
					<h2 class="text-sm font-semibold text-slate-100">{title}</h2>
					<p class="mt-0.5 text-xs text-slate-500">{description}</p>
				</div>
				{#if hasErrors}
					<span
						class="flex items-center gap-1 rounded-md bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-400"
					>
						<svg
							xmlns="http://www.w3.org/2000/svg"
							class="h-3.5 w-3.5"
							viewBox="0 0 20 20"
							fill="currentColor"
							aria-hidden="true"
						>
							<path
								fill-rule="evenodd"
								d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
								clip-rule="evenodd"
							/>
						</svg>
						{ruleErrors.size} invalid
					</span>
				{/if}
			</div>
			<div class="flex items-center gap-2">
				<button
					type="button"
					onclick={() => (previewOpen = !previewOpen)}
					class="flex items-center gap-1.5 rounded-lg border border-slate-600/60 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-indigo-500/50 hover:bg-indigo-600/10 hover:text-indigo-300"
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						class="h-3.5 w-3.5"
						viewBox="0 0 20 20"
						fill="currentColor"
						aria-hidden="true"
					>
						<path
							fill-rule="evenodd"
							d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"
							clip-rule="evenodd"
						/>
					</svg>
					{previewOpen ? 'Hide' : 'Show'} JSON
				</button>
				<button
					type="button"
					onclick={addRule}
					class="flex items-center gap-1.5 rounded-lg border border-slate-600/60 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-indigo-500/50 hover:bg-indigo-600/10 hover:text-indigo-300"
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						class="h-3.5 w-3.5"
						fill="none"
						viewBox="0 0 24 24"
						stroke="currentColor"
						stroke-width="2"
						aria-hidden="true"
					>
						<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
					</svg>
					Add Rule
				</button>
			</div>
		</div>

		{#if previewOpen}
			<div class="mb-4 overflow-hidden rounded-lg border border-slate-700 bg-slate-900">
				<div class="flex items-center justify-between border-b border-slate-700 px-3 py-2">
					<span class="text-xs font-medium text-slate-400">Compiled JSON</span>
					<button
						type="button"
						onclick={copyJson}
						class="flex items-center gap-1 text-xs text-slate-400 transition hover:text-indigo-400"
					>
						{#if copied}
							<svg
								xmlns="http://www.w3.org/2000/svg"
								class="h-3.5 w-3.5"
								viewBox="0 0 20 20"
								fill="currentColor"
								aria-hidden="true"
							>
								<path
									fill-rule="evenodd"
									d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
									clip-rule="evenodd"
								/>
							</svg>
							Copied!
						{:else if copyError}
							<svg
								xmlns="http://www.w3.org/2000/svg"
								class="h-3.5 w-3.5"
								viewBox="0 0 20 20"
								fill="currentColor"
								aria-hidden="true"
							>
								<path
									fill-rule="evenodd"
									d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
									clip-rule="evenodd"
								/>
							</svg>
							Failed
						{:else}
							<svg
								xmlns="http://www.w3.org/2000/svg"
								class="h-3.5 w-3.5"
								viewBox="0 0 20 20"
								fill="currentColor"
								aria-hidden="true"
							>
								<path d="M8 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z" />
								<path
									d="M6 3a2 2 0 00-2 2v11a2 2 0 002 2h8a2 2 0 002-2V5a2 2 0 00-2-2 3 3 0 01-3 3H9a3 3 0 01-3-3z"
								/>
							</svg>
							Copy
						{/if}
					</button>
				</div>
				<pre
					class="max-h-80 overflow-auto px-4 py-3 font-mono text-xs text-slate-300">{jsonPreview}</pre>
			</div>
		{/if}

		{#if rules.length > 0}
			<div class="space-y-4">
				{#each rules as rule, i (rule.id || `?rule[${i}]`)}
					<RuleBlock
						{rule}
						{gameConfig}
						ruleIndex={i}
						errors={ruleErrors.get(rule.id || `?rule[${i}]`) ?? []}
						onremove={() => removeRule(i)}
					/>
				{/each}
			</div>
		{:else}
			<p class="py-6 text-center text-sm text-slate-500">
				No rules yet. Add one to define game behavior.
			</p>
		{/if}
	</div>
</div>
