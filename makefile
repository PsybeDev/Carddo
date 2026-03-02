setup:
	cd backend && mix deps.get
	cd frontend && pnpm i

dev-backend:
	cd backend && mix phx.server

dev-frontend:
	cd frontend && pnpm run dev --open

dev:
	$(MAKE) -j2 dev-backend dev-frontend
