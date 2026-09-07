-- Every query must return zero rows before migration 000007 can be applied.
SELECT job_id,COUNT(*) FROM bids WHERE status='ACCEPTED' GROUP BY job_id HAVING COUNT(*)>1;
SELECT job_id,COUNT(*) FROM ratings GROUP BY job_id HAVING COUNT(*)>1;
SELECT job_id,COUNT(*) FROM transactions GROUP BY job_id HAVING COUNT(*)>1;
SELECT id,amount,counter_amount FROM bids WHERE amount<=0 OR counter_amount<=0;
SELECT provider_id,balance FROM provider_wallets WHERE balance<0;
-- Also audit existing positive wallets: earlier profile saves could duplicate balances.
-- Reconcile against external receipts and the ledger before making corrections.
