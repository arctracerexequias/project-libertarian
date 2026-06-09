-- Seed Data for Libertarian Marketplace

-- Insert Users
INSERT INTO users (id, email, password_hash, role, full_name, bio) VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'customer@example.com', '$2a$10$ViMZN4D7SkeXEUEZ.ShGFOkaqbnH.4m3/2CozbSMweFP8XTWuCG8i', 'customer', 'Juan Dela Cruz', 'I am a customer looking for home services.'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'provider@example.com', '$2a$10$ViMZN4D7SkeXEUEZ.ShGFOkaqbnH.4m3/2CozbSMweFP8XTWuCG8i', 'provider', 'Pedro Penduko', 'Expert plumber and electrician with 10 years experience.'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'admin@example.com', '$2a$10$ViMZN4D7SkeXEUEZ.ShGFOkaqbnH.4m3/2CozbSMweFP8XTWuCG8i', 'admin', 'System Admin', 'Platform administrator.'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'provider2@example.com', '$2a$10$ViMZN4D7SkeXEUEZ.ShGFOkaqbnH.4m3/2CozbSMweFP8XTWuCG8i', 'provider', 'Maria Makiling', 'Professional cleaner and home organizer.')
ON CONFLICT (email) DO NOTHING;

-- Insert Providers (specifically for the provider user)
INSERT INTO providers (user_id, bio, skills, reputation_score, is_verified, location) VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'Expert plumber and electrician with 10 years experience.', ARRAY['home_repair', 'plumbing', 'electrical'], 4.8, TRUE, ST_GeogFromText('POINT(121.0509 14.5496)')),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'Professional cleaner and home organizer.', ARRAY['home_repair', 'cleaning'], 4.5, TRUE, ST_GeogFromText('POINT(121.0500 14.5500)'))
ON CONFLICT (user_id) DO NOTHING;

-- Insert Provider Wallet
INSERT INTO provider_wallets (provider_id, balance, payment_method_type) VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 1000.00, 'GCASH'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 500.00, 'GCASH')
ON CONFLICT (provider_id) DO NOTHING;
