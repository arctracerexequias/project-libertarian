package service

import (
	"context"
	"fmt"
	"os"

	"github.com/google/uuid"
	"github.com/service-marketplace/payment-service/internal/domain"
	"github.com/stripe/stripe-go/v72"
	"github.com/stripe/stripe-go/v72/paymentintent"
	"github.com/stripe/stripe-go/v72/refund"
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
		Amount:        stripe.Int64(int64(amount * 100)),
		Currency:      stripe.String(string(stripe.CurrencyUSD)),
		CaptureMethod: stripe.String(string(stripe.PaymentIntentCaptureMethodManual)),
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
	tx, err := s.repo.GetTransactionByJobID(ctx, jobID)
	if err != nil {
		return fmt.Errorf("failed to retrieve transaction: %w", err)
	}

	// Capture the authorized amount
	_, err = paymentintent.Capture(tx.StripeIntentID, nil)
	if err != nil {
		return fmt.Errorf("failed to capture payment intent: %w", err)
	}

	return s.repo.UpdateTransactionStatus(ctx, jobID, "RELEASED")
}

func (s *paymentService) ProcessDailyCommissions(ctx context.Context) error {
	// This would normally be triggered by a cron job
	// 1. Fetch all active long-term jobs
	// 2. Identify providers and calculate daily commission (e.g. 10% of per-session budget)
	// 3. Deduct from provider_wallets table
	// 4. Record in wallet_transactions table
	fmt.Println("Processing daily provider commissions for long-term bookings...")
	return nil
}

func (s *paymentService) RefundEscrow(ctx context.Context, jobID string) error {
	tx, err := s.repo.GetTransactionByJobID(ctx, jobID)
	if err != nil {
		return fmt.Errorf("failed to retrieve transaction: %w", err)
	}

	// Since we use manual capture, if the status is still HELD, we just cancel the intent
	if tx.Status == "HELD" {
		_, err = paymentintent.Cancel(tx.StripeIntentID, nil)
		if err != nil {
			return fmt.Errorf("failed to cancel payment intent: %w", err)
		}
	} else if tx.Status == "RELEASED" {
		// If it was already captured, we need to issue a refund
		_, err = refund.New(&stripe.RefundParams{
			PaymentIntent: stripe.String(tx.StripeIntentID),
		})
		if err != nil {
			return fmt.Errorf("failed to refund payment intent: %w", err)
		}
	}

	return s.repo.UpdateTransactionStatus(ctx, jobID, "REFUNDED")
}
