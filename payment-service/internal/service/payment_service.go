package service

import (
	"context"
	"fmt"
	"os"

	"github.com/google/uuid"
	"github.com/service-marketplace/payment-service/internal/domain"
	"github.com/stripe/stripe-go/v72"
	"github.com/stripe/stripe-go/v72/paymentintent"
)

type paymentService struct {
	repo domain.PaymentRepository
}

func NewPaymentService(repo domain.PaymentRepository) domain.PaymentService {
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")
	return &paymentService{repo: repo}
}

func (s *paymentService) InitializeEscrow(ctx context.Context, jobID string, amount float64) (string, string, error) {
	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(int64(amount * 100)),
		Currency: stripe.String(string(stripe.CurrencyUSD)),
	}
	params.AddMetadata("job_id", jobID)
	
	pi, err := paymentintent.New(params)
	if err != nil {
		return "", "", fmt.Errorf("failed to create stripe payment intent: %w", err)
	}

	tx := &domain.Transaction{
		ID:             uuid.New().String(),
		JobID:          jobID,
		Amount:         amount,
		Status:         "HELD",
		StripeIntentID: pi.ID,
	}

	if err := s.repo.CreateTransaction(ctx, tx); err != nil {
		return "", "", err
	}

	return pi.ClientSecret, pi.ID, nil
}

func (s *paymentService) ReleaseEscrow(ctx context.Context, jobID string) error {
	// In a real implementation, you would trigger the Stripe transfer here
	// For this prototype, we'll just update the database status
	return s.repo.UpdateTransactionStatus(ctx, jobID, "RELEASED")
}

func (s *paymentService) RefundEscrow(ctx context.Context, jobID string) error {
	// In a real implementation, you would trigger the Stripe refund here
	return s.repo.UpdateTransactionStatus(ctx, jobID, "REFUNDED")
}
