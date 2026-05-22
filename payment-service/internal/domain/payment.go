package domain

import (
	"context"
	"time"
)

type Transaction struct {
	ID             string    `json:"id"`
	JobID          string    `json:"job_id"`
	Amount         float64   `json:"amount"`
	Status         string    `json:"status"` // HELD, RELEASED, REFUNDED
	StripeIntentID string    `json:"stripe_intent_id"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type PaymentRepository interface {
	CreateTransaction(ctx context.Context, tx *Transaction) error
	GetTransactionByJobID(ctx context.Context, jobID string) (*Transaction, error)
	UpdateTransactionStatus(ctx context.Context, jobID, status string) error
}

type PaymentService interface {
	InitializeEscrow(ctx context.Context, jobID string, amount float64) (string, string, error)
	ReleaseEscrow(ctx context.Context, jobID string) error
	RefundEscrow(ctx context.Context, jobID string) error
}
