package service

import (
	"context"
	"errors"
	"fmt"
	"github.com/google/uuid"
	"github.com/service-marketplace/payment-service/internal/domain"
	"time"
)

type paymentService struct {
	repo     domain.PaymentRepository
	provider domain.PaymentProvider
}

func NewPaymentService(repo domain.PaymentRepository, provider domain.PaymentProvider) domain.PaymentService {
	return &paymentService{repo: repo, provider: provider}
}
func (s *paymentService) InitializeEscrow(ctx context.Context, jobID, userID string) (*domain.Transaction, error) {
	var result *domain.Transaction
	err := s.repo.WithJob(ctx, jobID, func(j domain.PaymentJob, store domain.PaymentStore) error {
		if userID == "" || j.CustomerID != userID {
			return domain.ErrForbidden
		}
		if j.PaymentMethod != "ONLINE" || j.ProviderID == "" || j.AmountMinor <= 0 || (j.Status != "ACCEPTED" && j.Status != "EN_ROUTE" && j.Status != "IN_PROGRESS") {
			return domain.ErrState
		}
		t, err := store.Get(ctx)
		if err != nil {
			return err
		}
		if t == nil {
			t = &domain.Transaction{ID: uuid.New().String(), JobID: j.ID, AmountMinor: j.AmountMinor, Currency: "PHP", Status: "PENDING", CreatedAt: time.Now().UTC()}
			if err = store.Save(ctx, t); err != nil {
				return err
			}
		}
		if t.AmountMinor != j.AmountMinor || t.Currency != "PHP" {
			return domain.ErrState
		}
		if t.CheckoutID == "" {
			// Stripe retains idempotency keys for at least 24h. An ambiguous old attempt
			// needs operator reconciliation; never risk silently making a second charge.
			if time.Since(t.CreatedAt) > 23*time.Hour {
				return fmt.Errorf("payment attempt needs support reconciliation")
			}
			checkout, err := s.provider.CreateCheckout(ctx, t)
			if err != nil {
				return err
			}
			t.CheckoutID, t.CheckoutURL = checkout.ID, checkout.URL
			if err = store.Save(ctx, t); err != nil {
				return err
			}
		}
		if err = s.sync(ctx, store, t); err != nil {
			return err
		}
		if t.Status != "PENDING" && t.Status != "HELD" {
			return domain.ErrState
		}
		result = t
		return nil
	})
	return result, err
}
func (s *paymentService) sync(ctx context.Context, store domain.PaymentStore, t *domain.Transaction) error {
	if t.CheckoutID == "" {
		if t.StripeIntentID == "" {
			return nil
		}
		t.CheckoutID = "intent:" + t.StripeIntentID
	}
	checkout, err := s.provider.Checkout(ctx, t.CheckoutID)
	if err != nil {
		return err
	}
	if checkout.AmountMinor != t.AmountMinor || checkout.Currency != t.Currency {
		return fmt.Errorf("payment amount or currency mismatch")
	}
	t.StripeIntentID = checkout.IntentID
	// Refunded is terminal; Stripe's intent still reports succeeded after refund.
	if t.Status != "REFUNDED" {
		t.Status = checkout.Status
	}
	if t.Status != "PENDING" {
		t.CheckoutURL = ""
	}
	return store.Save(ctx, t)
}
func (s *paymentService) GetEscrow(ctx context.Context, jobID, userID string) (*domain.Transaction, error) {
	var result *domain.Transaction
	err := s.repo.WithJob(ctx, jobID, func(j domain.PaymentJob, store domain.PaymentStore) error {
		if userID == "" || (j.CustomerID != userID && j.ProviderID != userID) {
			return domain.ErrForbidden
		}
		t, err := store.Get(ctx)
		if err != nil {
			return err
		}
		if t == nil {
			result = &domain.Transaction{JobID: jobID, Status: "UNFUNDED", Currency: "PHP"}
			return nil
		}
		if err = s.sync(ctx, store, t); err != nil {
			return err
		}
		if j.Status == "CANCELLED" {
			if err = s.refund(ctx, store, t); err != nil {
				return err
			}
		}
		copy := *t
		if userID != j.CustomerID {
			copy.CheckoutURL = ""
		}
		result = &copy
		return nil
	})
	return result, err
}
func (s *paymentService) ReleaseEscrow(ctx context.Context, jobID, userID string) error {
	return s.repo.WithJob(ctx, jobID, func(j domain.PaymentJob, store domain.PaymentStore) error {
		if userID == "" || j.CustomerID != userID {
			return domain.ErrForbidden
		}
		if j.Status != "COMPLETED" {
			return domain.ErrState
		}
		t, err := store.Get(ctx)
		if err != nil {
			return err
		}
		if t == nil {
			return domain.ErrState
		}
		if err = s.sync(ctx, store, t); err != nil {
			return err
		}
		if t.Status == "RELEASED" {
			return nil
		}
		if t.Status != "HELD" {
			return domain.ErrState
		}
		if err = s.provider.Capture(ctx, t.StripeIntentID, t.ID+"-capture"); err != nil {
			return err
		}
		t.Status = "RELEASED"
		return store.Save(ctx, t)
	})
}
func (s *paymentService) refund(ctx context.Context, store domain.PaymentStore, t *domain.Transaction) error {
	if t.Status == "REFUNDED" || t.Status == "EXPIRED" {
		return nil
	}
	if t.CheckoutID == "" {
		return fmt.Errorf("checkout creation needs reconciliation before refund")
	}
	if err := s.provider.Refund(ctx, t.CheckoutID, t.StripeIntentID, t.ID+"-refund"); err != nil {
		return err
	}
	t.Status = "REFUNDED"
	t.CheckoutURL = ""
	return store.Save(ctx, t)
}
func (s *paymentService) RefundEscrow(ctx context.Context, jobID, userID string) error {
	return s.repo.WithJob(ctx, jobID, func(j domain.PaymentJob, store domain.PaymentStore) error {
		if userID == "" || (j.CustomerID != userID && j.ProviderID != userID) {
			return domain.ErrForbidden
		}
		if j.Status != "CANCELLED" {
			return domain.ErrState
		}
		t, err := store.Get(ctx)
		if err != nil || t == nil {
			return err
		}
		if err = s.sync(ctx, store, t); err != nil {
			return err
		}
		return s.refund(ctx, store, t)
	})
}
func (s *paymentService) Reconcile(ctx context.Context) error {
	ids, err := s.repo.ReconciliationJobs(ctx)
	if err != nil {
		return err
	}
	var failures []error
	for _, id := range ids {
		if err = s.repo.WithJob(ctx, id, func(j domain.PaymentJob, store domain.PaymentStore) error {
			t, err := store.Get(ctx)
			if err != nil || t == nil {
				return err
			}
			if t.CheckoutID == "" && t.StripeIntentID == "" {
				if time.Since(t.CreatedAt) > 23*time.Hour {
					return fmt.Errorf("ambiguous checkout requires operator reconciliation")
				}
				checkout, err := s.provider.CreateCheckout(ctx, t)
				if err != nil {
					return err
				}
				t.CheckoutID, t.CheckoutURL = checkout.ID, checkout.URL
				if err = store.Save(ctx, t); err != nil {
					return err
				}
			}
			if err = s.sync(ctx, store, t); err != nil {
				return err
			}
			if j.Status == "CANCELLED" {
				return s.refund(ctx, store, t)
			}
			return nil
		}); err != nil {
			failures = append(failures, fmt.Errorf("job %s: %w", id, err))
		}
	}
	return errors.Join(failures...)
}
