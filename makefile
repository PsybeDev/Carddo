.PHONY: setup dev dev-backend dev-frontend build-wasm

setup:
	$(MAKE) build-wasm
	cd backend && mix deps.get
	cd frontend && pnpm i

build-wasm:
	cd ditto_engine/ditto_wasm && wasm-pack build --target web

dev-backend:
	cd backend && mix phx.server

dev-frontend:
	cd frontend && pnpm run dev --open

dev:
	$(MAKE) -j2 dev-backend dev-frontend
