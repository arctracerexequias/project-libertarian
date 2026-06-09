-- Add missing tables and columns from schema.sql

-- Establishments Table
CREATE TABLE IF NOT EXISTS establishments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES providers(user_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    business_type TEXT NOT NULL, -- e.g., 'Repair Shop', 'Salon'
    registration_number TEXT,
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Provider Wallet Table
CREATE TABLE IF NOT EXISTS provider_wallets (
    provider_id UUID PRIMARY KEY REFERENCES providers(user_id) ON DELETE CASCADE,
    balance DECIMAL(12, 2) DEFAULT 0.0,
    payment_method_type TEXT, -- 'GCASH' or 'MAYA'
    payment_method_id TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Wallet Transactions (for daily commission deductions)
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES providers(user_id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL,
    type TEXT NOT NULL, -- 'CREDIT' or 'DEBIT' (commission)
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Update Jobs Table with Recurrence
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS recurrence_type TEXT DEFAULT 'ONCE' CHECK (recurrence_type IN ('ONCE', 'DAILY', 'WEEKLY', 'BI_MONTHLY', 'MONTHLY'));
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS total_occurrences INT DEFAULT 1;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS parent_job_id UUID REFERENCES jobs(id);

-- Update Users Table
ALTER TABLE users ADD COLUMN IF NOT EXISTS rebook_count INT DEFAULT 0;
