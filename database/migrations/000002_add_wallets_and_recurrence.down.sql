-- Revert missing tables and columns

ALTER TABLE users DROP COLUMN IF EXISTS rebook_count;

ALTER TABLE jobs DROP COLUMN IF EXISTS parent_job_id;
ALTER TABLE jobs DROP COLUMN IF EXISTS total_occurrences;
ALTER TABLE jobs DROP COLUMN IF EXISTS recurrence_type;

DROP TABLE IF EXISTS wallet_transactions;
DROP TABLE IF EXISTS provider_wallets;
DROP TABLE IF EXISTS establishments;
