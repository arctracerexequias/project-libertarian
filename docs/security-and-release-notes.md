# Security and release changes

## Setup

1. Copy `.env.example` to `.env`. Set independent `JWT_SECRET`, `GATEWAY_SECRET`, and `ADMIN_PASSWORD` values, plus a URL-safe `POSTGRES_PASSWORD`. Generate secrets with `openssl rand -hex 32`. JWT and gateway secrets need at least 32 characters.
2. Start with `docker compose up --build`. Test accounts are now opt-in: `docker compose --profile dev up --build`. Wait for `db-seed` to finish before logging in with a test account.
3. Build mobile apps with `--dart-define=API_BASE_URL=https://your-host/api/v1`. Release builds reject plaintext HTTP. For a physical development device, use its reachable LAN host and explicitly set `GATEWAY_BIND_ADDRESS` for that development environment. The default gateway and admin bindings are loopback only.
4. Terminate HTTPS at your deployment proxy. Backend services stay on the private Compose network. `GATEWAY_SECRET` authenticates identity propagation; never expose it to an app. Configure `WS_ALLOWED_ORIGINS` as a comma-separated list for browser chat clients; native clients do not send an Origin header.

## Existing databases

Back up the existing database before changing volumes or applying migration 000007. The new named `marketplace-data` volume does **not** automatically import data from an older anonymous Docker volume. Preserve that volume and restore its backup into the intended database before switching traffic. Changing `POSTGRES_PASSWORD` does not rotate an already initialized PostgreSQL role automatically; coordinate the role password and service configuration when upgrading an existing database.

Run `scripts/migration-preflight.sql` against a copy of the database. Migration 000007 rejects duplicate accepted bids, duplicate job payments/ratings, nonpositive bid amounts, and negative wallets. It deliberately does not guess which financial records to delete. Audit existing wallet balances against receipts/ledger entries because previous profile saves could inflate them. Check existing verified accounts as well: the former self-verification endpoint could have granted verification without review. The patch prevents future self-verification; it does not guess which existing approvals are legitimate.

Use `scripts/backup-db.sh /secure/path/backup.dump` for a restricted-permission custom-format dump. Store backups off the host and schedule them through your deployment scheduler. Verify restoration using `scripts/restore-db.sh backup.dump restore_check`, which always creates a new database rather than overwriting the running one. Review restored counts and critical bookings before deleting a backup or switching databases. Production backup scheduling and off-host storage require deployment-specific configuration.

## Payments

New online bookings use Stripe hosted card checkout in PHP, with integer minor units derived from the accepted bid. The app never supplies the authoritative charge amount. Cash remains available. GCash and Maya have been removed from new-booking choices because those integrations are not implemented.

Set a Stripe test secret and a reachable HTTPS `CHECKOUT_RETURN_URL` before testing on devices. The return page does not declare success: the app refreshes status from the backend, which retrieves current provider state. `PENDING` means checkout is not yet authorized; `HELD` means authorization is confirmed; `RELEASED` means capture is confirmed; `REFUNDED` means a refund or authorization cancellation succeeded. Stripe card authorization/capture is not a separate escrow account. Provider bank payouts/Stripe Connect onboarding are not implemented by this change; do not present capture as a completed provider payout.

The adapter follows [Stripe manual capture](https://docs.stripe.com/payments/place-a-hold-on-a-payment-method) and [idempotent requests](https://docs.stripe.com/api/idempotent_requests). Card authorizations expire, so this flow requires service completion within the provider's authorization window. Expired authorizations and legacy unsupported payment methods need support handling; they are never shown as secured funds.

The payment service polls persistent transaction/job state every 30 seconds. Job locks serialize checkout, capture, cancellation and refund decisions. Cancelled jobs remain eligible for refund reconciliation after restarts or provider outages. Retries retain the same provider idempotency key. An ambiguous checkout attempt older than 23 hours is blocked for operator reconciliation instead of risking a duplicate charge. Monitor `Payment reconciliation` errors; a prolonged outage or expired attempt needs operator attention. The worker processes up to 100 oldest attempts per pass.

Existing transactions retain USD currency and their original payment intent; migration does not relabel old USD amounts as PHP or silently create replacement charges. Live Stripe authorization, capture, refund, and settlement must be verified using the deployment's account and credentials before accepting real money.

## Verification and boosts

`POST /auth/verify-me` is retained as a read-only session validation endpoint. Providers request review through `POST /auth/verification/request`. The admin dashboard lists pending requests and requires an explicit approve/reject decision plus a review note; only the Basic Auth protected admin service changes verification state. Identity evidence must be reviewed through the operator's verification process; this does not add an automated KYC vendor or document-upload integration.

Boosts cost PHP 199 (coverage) or PHP 299 (roam) for seven days, matching the existing advertised prices. Purchases atomically debit available wallet funds, create a ledger entry, and activate the benefit. Repeated requests during an active purchase do not charge twice. Toggling coverage does not change its paid expiry. Wallet funding must use a reconciled funding process; profile updates no longer credit funds.

## Validation

Run `scripts/test-backend.sh`. Set `TEST_DATABASE_URL` to enable isolated database regressions; each test creates and drops only its own schema. These local fixtures exercise relational logic and migration 000007, not spatial operations. CI additionally applies all migrations to real PostGIS, rolls back/reapplies 000007, and runs the development seed.

Run `flutter test` in `mobile/shared_core`, `mobile/customer_app`, and `mobile/provider_app`. CI covers all three packages. Payment provider tests use an injected HTTP transport and make no real charges. The provider app test now checks signed-out login behavior instead of the unrelated Flutter counter sample.

### Local verification results

Go race tests and `go vet` passed across all workspace modules. PostgreSQL regression tests passed in an isolated local instance, including the new relational migration. All 25 Flutter tests passed across the three packages. Shared-core analysis reported no errors but retained existing warnings and informational lints. Compose configuration and admin JavaScript syntax checks passed. The full PostGIS migration job is configured in CI; it was not run locally because the Docker daemon is inaccessible and the native database has no PostGIS extension. No existing application database was migrated and no real payment was made.
