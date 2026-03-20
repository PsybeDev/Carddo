<script lang="ts">
	let { children } = $props();
</script>

<div class="flex min-h-screen flex-col items-center justify-center bg-[#0f1117] px-4">
	<div class="mb-8 flex items-center gap-2">
		<svg
			width="28"
			height="28"
			viewBox="0 0 28 28"
			fill="none"
			xmlns="http://www.w3.org/2000/svg"
			aria-hidden="true"
		>
			<rect width="28" height="28" rx="6" fill="url(#grad)" />
			<path d="M7 14L14 7L21 14L14 21L7 14Z" fill="white" opacity="0.9" />
			<defs>
				<linearGradient id="grad" x1="0" y1="0" x2="28" y2="28">
					<stop offset="0%" stop-color="#6366f1" />
					<stop offset="100%" stop-color="#8b5cf6" />
				</linearGradient>
			</defs>
		</svg>
		<span class="text-xl font-semibold tracking-tight text-slate-100">Carddo</span>
	</div>

	<div
		class="w-full max-w-md rounded-xl border border-slate-700/50 bg-[#1a1d27] p-8 shadow-2xl shadow-black/40"
	>
		{@render children()}
	</div>

	<p class="mt-6 text-xs text-slate-600">Card Engine Platform</p>
</div>
