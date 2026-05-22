package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/service-marketplace/payment-service/internal/domain"
)

type paymentRepo struct {
	db *pgxpool.Pool
}

func NewPaymentRepository(db *pgxpool.Pool) domain.PaymentRepository {
	return &paymentRepo{db: db}
}

func (r *paymentRepo) CreateTransaction(ctx context.Context, tx *domain.Transaction) error {
	_, err := r.db.Exec(ctx,
		"INSERT INTO transactions (id, job_id, amount, status, stripe_intent_id) VALUES ($1, $2, $3, $4, $5)",
		tx.ID, tx.JobID, tx.Amount, tx.Status, tx.StripeIntentID)
	if err != nil {
		return fmt.Errorf("failed to create transaction: %w", err)
	}
	return nil
}

func (r *paymentRepo) GetTransactionByJobID(ctx context.Context, jobID string) (*domain.Transaction, error) {
	var tx domain.Transaction
	err := r.db.QueryRow(ctx,
		"SELECT id, job_id, amount, status, stripe_intent_id, created_at FROM transactions WHERE job_id = $1",
		jobID).Scan(&tx.ID, &tx.JobID, &tx.Amount, &tx.Status, &tx.StripeIntentID, &tx.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to get transaction: %w", err)
	}
	return &tx, nil
}

func (r *paymentRepo) UpdateTransactionStatus(ctx context.Context, jobID, status string) error {
	_, err := r.db.Exec(ctx,
		"UPDATE transactions SET status = $1, updated_at = NOW() WHERE job_id = $2",
		status, jobID)
	if err != nil {
		return fmt.Errorf("failed to update transaction status: %w", err)
	}
	return nil
}
