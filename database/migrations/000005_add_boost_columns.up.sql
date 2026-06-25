-- Add boost expiry columns to providers table
ALTER TABLE providers
    ADD COLUMN IF NOT EXISTS coverage_boost_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS roam_boost_expires_at TIMESTAMPTZ;
