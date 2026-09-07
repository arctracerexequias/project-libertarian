-- Fail on inconsistent existing financial/booking data rather than silently
-- deleting or merging records. Review duplicates before applying this migration.
CREATE UNIQUE INDEX bids_one_accepted_per_job ON bids(job_id) WHERE status='ACCEPTED';
CREATE UNIQUE INDEX ratings_one_per_job ON ratings(job_id);
CREATE UNIQUE INDEX transactions_one_per_job ON transactions(job_id);
ALTER TABLE bids ADD CONSTRAINT bids_amount_positive CHECK(amount>0);
ALTER TABLE bids ADD CONSTRAINT bids_counter_amount_positive CHECK(counter_amount IS NULL OR counter_amount>0);
ALTER TABLE provider_wallets ADD CONSTRAINT wallet_nonnegative CHECK(balance>=0);
ALTER TABLE providers ADD COLUMN coverage_boost_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE transactions DROP CONSTRAINT transactions_status_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_status_check CHECK(status IN ('PENDING','HELD','RELEASED','REFUNDED','EXPIRED'));
ALTER TABLE transactions ALTER COLUMN status SET DEFAULT 'PENDING';
-- Existing intents were created in USD. Do not relabel old money as PHP.
ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD';
ALTER TABLE transactions ALTER COLUMN currency SET DEFAULT 'PHP';
ALTER TABLE transactions ADD COLUMN checkout_session_id TEXT UNIQUE;
ALTER TABLE transactions ADD COLUMN checkout_url TEXT;
CREATE TABLE verification_requests (
 provider_id UUID PRIMARY KEY REFERENCES providers(user_id) ON DELETE CASCADE,
 status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','APPROVED','REJECTED')),
 requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 reviewed_at TIMESTAMPTZ,
 review_note TEXT,
 reviewed_by TEXT
);
CREATE INDEX messages_job_created ON messages(job_id,created_at);
CREATE INDEX bids_job_status ON bids(job_id,status);
CREATE INDEX transactions_reconcile ON transactions(status,updated_at);
