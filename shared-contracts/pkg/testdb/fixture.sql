-- Only relational columns used by these regressions; no spatial emulation.
CREATE TABLE users(id uuid PRIMARY KEY,email text,password_hash text,full_name text,role text,is_verified boolean DEFAULT false,bio text,skills text[]);
CREATE TABLE providers(user_id uuid PRIMARY KEY REFERENCES users(id),bio text,skills text[],reputation_score numeric,is_verified boolean DEFAULT false,coverage_boost_expires_at timestamptz,roam_boost_expires_at timestamptz);
CREATE TABLE provider_wallets(provider_id uuid PRIMARY KEY REFERENCES providers(user_id),balance numeric DEFAULT 0,updated_at timestamptz DEFAULT now());
CREATE TABLE wallet_transactions(id uuid DEFAULT gen_random_uuid(),provider_id uuid REFERENCES providers(user_id),amount numeric,type text,description text);
CREATE TABLE jobs(id uuid PRIMARY KEY,customer_id uuid REFERENCES users(id),status text,payment_method text DEFAULT 'ONLINE',updated_at timestamptz DEFAULT now());
CREATE TABLE bids(id uuid PRIMARY KEY,job_id uuid REFERENCES jobs(id),provider_id uuid REFERENCES providers(user_id),amount numeric,estimated_time text,message text,status text,counter_amount numeric,counter_by uuid,decline_reason text);
CREATE TABLE ratings(id uuid DEFAULT gen_random_uuid(),job_id uuid REFERENCES jobs(id),provider_id uuid REFERENCES users(id),customer_id uuid REFERENCES users(id),score int CHECK(score BETWEEN 1 AND 5),comment text);
CREATE TABLE transactions(id uuid PRIMARY KEY,job_id uuid REFERENCES jobs(id),amount numeric,status text DEFAULT 'HELD' CONSTRAINT transactions_status_check CHECK(status IN ('HELD','RELEASED','REFUNDED')),stripe_intent_id text,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now());
CREATE TABLE messages(id uuid DEFAULT gen_random_uuid(),job_id uuid REFERENCES jobs(id),sender_id uuid REFERENCES users(id),content text,created_at timestamptz DEFAULT now());
INSERT INTO users(id,role) VALUES ('00000000-0000-0000-0000-000000000001','customer'),('00000000-0000-0000-0000-000000000002','provider'),('00000000-0000-0000-0000-000000000003','provider');
INSERT INTO providers(user_id) SELECT id FROM users WHERE role='provider';
INSERT INTO provider_wallets(provider_id,balance) SELECT user_id,1000 FROM providers;
INSERT INTO jobs(id,customer_id,status) VALUES('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000001','PUBLISHED');
INSERT INTO bids(id,job_id,provider_id,amount,status) VALUES('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000002',500,'PENDING');
