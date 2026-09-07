package postgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/service-marketplace/payment-service/internal/domain"
)

type paymentRepo struct{ db *pgxpool.Pool }
type paymentStore struct {
	tx    pgx.Tx
	jobID string
}

func NewPaymentRepository(db *pgxpool.Pool) domain.PaymentRepository { return &paymentRepo{db: db} }
func (r *paymentRepo) WithJob(ctx context.Context, id string, fn func(domain.PaymentJob, domain.PaymentStore) error) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	var j domain.PaymentJob
	err = tx.QueryRow(ctx, `SELECT id,customer_id,status,payment_method FROM jobs WHERE id=$1 FOR UPDATE`, id).Scan(&j.ID, &j.CustomerID, &j.Status, &j.PaymentMethod)
	if err != nil {
		return err
	}
	err = tx.QueryRow(ctx, "SELECT provider_id,(amount*100)::bigint FROM bids WHERE job_id=$1 AND status='ACCEPTED'", id).Scan(&j.ProviderID, &j.AmountMinor)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	actionErr := fn(j, &paymentStore{tx: tx, jobID: id})
	// In particular, persist a PENDING reservation after a network timeout. Retrying
	// must use the same idempotency key, never create a fresh charge identity.
	if _, err = tx.Exec(ctx, "UPDATE transactions SET updated_at=NOW() WHERE job_id=$1", id); err != nil {
		return err
	}
	if err = tx.Commit(ctx); err != nil {
		return err
	}
	return actionErr
}
func (s *paymentStore) Get(ctx context.Context) (*domain.Transaction, error) {
	var t domain.Transaction
	err := s.tx.QueryRow(ctx, `SELECT id,job_id,(amount*100)::bigint,currency,status,COALESCE(stripe_intent_id,''),
 COALESCE(checkout_session_id,''),COALESCE(checkout_url,''),created_at FROM transactions WHERE job_id=$1`, s.jobID).Scan(&t.ID, &t.JobID, &t.AmountMinor, &t.Currency, &t.Status, &t.StripeIntentID, &t.CheckoutID, &t.CheckoutURL, &t.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &t, err
}
func (s *paymentStore) Save(ctx context.Context, t *domain.Transaction) error {
	_, err := s.tx.Exec(ctx, `INSERT INTO transactions(id,job_id,amount,currency,status,stripe_intent_id,checkout_session_id,checkout_url,created_at)
 VALUES($1,$2,$3::numeric/100,$4,$5,NULLIF($6,''),NULLIF($7,''),NULLIF($8,''),$9)
 ON CONFLICT(job_id) DO UPDATE SET status=EXCLUDED.status,stripe_intent_id=EXCLUDED.stripe_intent_id,
 checkout_session_id=EXCLUDED.checkout_session_id,checkout_url=EXCLUDED.checkout_url,updated_at=NOW()`, t.ID, t.JobID, t.AmountMinor, t.Currency, t.Status, t.StripeIntentID, t.CheckoutID, t.CheckoutURL, t.CreatedAt)
	return err
}
func (r *paymentRepo) ReconciliationJobs(ctx context.Context) ([]string, error) {
	rows, err := r.db.Query(ctx, `SELECT t.job_id FROM transactions t JOIN jobs j ON j.id=t.job_id
 WHERE t.status IN ('PENDING','HELD') OR (j.status='CANCELLED' AND t.status='RELEASED') ORDER BY t.updated_at LIMIT 100`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	ids := []string{}
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}
