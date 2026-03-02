.PHONY: setup dev dev-backend dev-frontend build-wasm

setup:
	cd backend && mix deps.get
	cd frontend && pnpm i
	$(MAKE) build-wasm

build-wadm:
	cd ditto_engine/ditto_wasm && wasm-pack build --target web

dev-backend:
	cd backend && mix phx.server

dev-frontend:
	cd frontend && pnpm run dev --open

dev:
	$(MAKE) -j2 dev-backend dev-frontend
