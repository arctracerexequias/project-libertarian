ALTER TABLE jobs
ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'ONLINE';

UPDATE jobs
SET payment_method = 'CASH'
WHERE description ILIKE '%Payment: Cash after service%'
   OR description ILIKE '%Payment: Cash on Delivery%';

ALTER TABLE jobs
DROP CONSTRAINT IF EXISTS jobs_payment_method_check;

ALTER TABLE jobs
ADD CONSTRAINT jobs_payment_method_check
CHECK (payment_method IN ('ONLINE', 'GCASH', 'MAYA', 'CASH'));
