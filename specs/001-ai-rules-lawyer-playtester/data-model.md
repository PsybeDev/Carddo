# Data Model: AI Rules Lawyer & Playtester

## Entities

### BalanceReport
Stores the results of an AI simulation audit.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Owner of the report |
| `card_set_version` | String | Version of the cards being tested |
| `status` | String | `pending`, `running`, `completed`, `failed` |
| `report_data` | JSONB | The actual audit findings (win rates, anomalies) |
| `inserted_at` | Timestamp | Creation time |

### User (Extension)
Add feature flag for monetization.

| Field | Type | Description |
|-------|------|-------------|
| `has_ai_audit_access` | Boolean | Default: `false`. Gated by subscription. |

## Relationships
- `User` has many `BalanceReports`.
- `BalanceReport` belongs to `User`.
