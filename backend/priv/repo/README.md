# Seed Data

Run from the repo root:

```bash
make seed
```

Or from `backend/`:

```bash
mix run priv/repo/seeds.exs
```

Idempotent — safe to run multiple times.

## Demo Credentials

| Field    | Value              |
|----------|--------------------|
| Email    | `demo@carddo.dev`  |
| Password | `demopassword`     |
| Tier     | `pro`              |

## Ditto Demo Game

**Zones:** Deck (Hidden), Hand (OwnerOnly), Battlefield (Public), Discard (Public)

**Starting zone:** Deck

**State checks:** Health <= 0 → move to Discard

**Cards:** 10 creatures with Health 20, Attack 1–5, each with a Strike ability.

**Decks:** Deck Alpha (cards 1–5), Deck Beta (cards 6–10), 1 copy each.
