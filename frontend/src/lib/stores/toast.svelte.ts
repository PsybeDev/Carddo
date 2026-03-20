type Toast = { id: number; message: string; type: 'error' | 'success' | 'info' };

let toasts = $state<Toast[]>([]);
let _nextId = 0;

export const toastStore = {
	get list() {
		return toasts;
	},
	show(message: string, type: Toast['type'] = 'error') {
		const id = ++_nextId;
		toasts = [...toasts, { id, message, type }];
		setTimeout(() => {
			toasts = toasts.filter((t) => t.id !== id);
		}, 4000);
	}
};
