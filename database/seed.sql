-- Development test accounts for Libertarian Marketplace.
-- All three accounts use the password: OdgTest123!
-- This script is idempotent and may be safely reapplied.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- This UUID belonged to a legacy second provider. Remove its provider-only
-- records before reusing it for the second requested customer account.
DELETE FROM providers
WHERE user_id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14';

INSERT INTO users (
    id,
    email,
    password_hash,
    role,
    full_name,
    bio,
    is_verified
) VALUES
(
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'customer1@odg.test',
    crypt('OdgTest123!', gen_salt('bf', 10)),
    'customer',
    'Juan Dela Cruz',
    'Test customer account for booking services.',
    TRUE
),
(
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14',
    'customer2@odg.test',
    crypt('OdgTest123!', gen_salt('bf', 10)),
    'customer',
    'Maria Santos',
    'Test customer account for booking services.',
    TRUE
),
(
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12',
    'provider1@odg.test',
    crypt('OdgTest123!', gen_salt('bf', 10)),
    'provider',
    'Pedro Penduko',
    'Verified test provider for plumbing and electrical services.',
    TRUE
)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    full_name = EXCLUDED.full_name,
    bio = EXCLUDED.bio,
    is_verified = EXCLUDED.is_verified,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO providers (
    user_id,
    bio,
    skills,
    reputation_score,
    is_verified,
    location
) VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12',
    'Verified test provider for plumbing and electrical services.',
    ARRAY['home_repair', 'plumbing', 'electrical'],
    4.8,
    TRUE,
    ST_GeogFromText('POINT(121.0509 14.5496)')
)
ON CONFLICT (user_id) DO UPDATE SET
    bio = EXCLUDED.bio,
    skills = EXCLUDED.skills,
    reputation_score = EXCLUDED.reputation_score,
    is_verified = EXCLUDED.is_verified,
    location = EXCLUDED.location;

INSERT INTO provider_wallets (
    provider_id,
    balance,
    payment_method_type
) VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12',
    1000.00,
    'GCASH'
)
ON CONFLICT (provider_id) DO UPDATE SET
    balance = EXCLUDED.balance,
    payment_method_type = EXCLUDED.payment_method_type;
