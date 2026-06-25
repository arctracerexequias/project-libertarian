-- Revert boost expiry columns from providers table
ALTER TABLE providers
    DROP COLUMN IF EXISTS coverage_boost_expires_at,
    DROP COLUMN IF EXISTS roam_boost_expires_at;
