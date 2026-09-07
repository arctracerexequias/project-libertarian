-- This intentionally fails while new payment states remain; reconcile them
-- before downgrading, rather than incorrectly declaring them funded.
ALTER TABLE transactions DROP CONSTRAINT transactions_status_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_status_check CHECK(status IN ('HELD','RELEASED','REFUNDED'));
ALTER TABLE transactions ALTER COLUMN status SET DEFAULT 'HELD';
ALTER TABLE transactions DROP COLUMN checkout_url, DROP COLUMN checkout_session_id, DROP COLUMN currency;
ALTER TABLE providers DROP COLUMN coverage_boost_enabled;
ALTER TABLE provider_wallets DROP CONSTRAINT wallet_nonnegative;
ALTER TABLE bids DROP CONSTRAINT bids_counter_amount_positive, DROP CONSTRAINT bids_amount_positive;
DROP INDEX bids_one_accepted_per_job;
DROP INDEX ratings_one_per_job;
DROP INDEX transactions_one_per_job;
DROP INDEX messages_job_created;
DROP INDEX bids_job_status;
DROP INDEX transactions_reconcile;
DROP TABLE verification_requests;
