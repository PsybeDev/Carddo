.PHONY: setup dev dev-backend dev-frontend build-wasm generate-types seed

setup:
	$(MAKE) build-wasm
	$(MAKE) generate-types
	cd backend && mix deps.get
	cd frontend && pnpm i

build-wasm:
	cd ditto_engine/ditto_wasm && wasm-pack build --target web

generate-types:
	cd ditto_engine && cargo test -p ditto_core --features ts --test export_types

dev-backend:
	cd backend && mix phx.server

dev-frontend:
	cd frontend && pnpm run dev --open

dev: generate-types
	$(MAKE) -j2 dev-backend dev-frontend

seed:
	cd backend && mix run priv/repo/seeds.exs
