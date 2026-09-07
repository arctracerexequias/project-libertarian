package service

import (
	"context"
	"errors"
	"github.com/service-marketplace/payment-service/internal/domain"
	"sync"
	"testing"
)

func TestPaymentsRejectOutsiders(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{}
	svc := NewPaymentService(repo, provider)
	ctx := context.Background()
	if _, err := svc.InitializeEscrow(ctx, "job", "outsider"); !errors.Is(err, domain.ErrForbidden) {
		t.Fatal(err)
	}
	if _, err := svc.GetEscrow(ctx, "job", "outsider"); !errors.Is(err, domain.ErrForbidden) {
		t.Fatal(err)
	}
	if err := svc.ReleaseEscrow(ctx, "job", "outsider"); !errors.Is(err, domain.ErrForbidden) {
		t.Fatal(err)
	}
	if err := svc.RefundEscrow(ctx, "job", "outsider"); !errors.Is(err, domain.ErrForbidden) {
		t.Fatal(err)
	}
	if repo.tx != nil || provider.created != 0 {
		t.Fatal("unauthorized payment side effect")
	}
}
func TestCheckoutUsesServerAmountAndRequiresConfirmation(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{}
	svc := NewPaymentService(repo, provider)
	ctx := context.Background()
	tx, err := svc.InitializeEscrow(ctx, "job", "customer")
	if err != nil {
		t.Fatal(err)
	}
	if tx.Status != "PENDING" || tx.AmountMinor != 125050 || tx.Currency != "PHP" {
		t.Fatalf("incorrect transaction: %+v", tx)
	}
	provider.checkout.Status = "HELD"
	tx, err = svc.GetEscrow(ctx, "job", "provider")
	if err != nil {
		t.Fatal(err)
	}
	if tx.Status != "HELD" || tx.CheckoutURL != "" {
		t.Fatal("incorrect provider payment view")
	}
}
func TestRetryPreservesCheckoutIdentity(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{failure: errors.New("timeout")}
	svc := NewPaymentService(repo, provider)
	if _, err := svc.InitializeEscrow(context.Background(), "job", "customer"); err == nil {
		t.Fatal("expected timeout")
	}
	if repo.tx == nil || repo.tx.Status != "PENDING" {
		t.Fatal("reservation lost")
	}
	id := repo.tx.ID
	provider.failure = nil
	if _, err := svc.InitializeEscrow(context.Background(), "job", "customer"); err != nil {
		t.Fatal(err)
	}
	if len(provider.keys) != 2 || provider.keys[0] != id || provider.keys[1] != id {
		t.Fatal("retry used a new idempotency key")
	}
}
func TestConcurrentCheckoutCreatesOnce(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{}
	svc := NewPaymentService(repo, provider)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, err := svc.InitializeEscrow(context.Background(), "job", "customer"); err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	if provider.created != 1 {
		t.Fatalf("created %d checkouts", provider.created)
	}
}
func TestCaptureRequiresCompletionAndIsIdempotent(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{}
	svc := NewPaymentService(repo, provider)
	ctx := context.Background()
	if _, err := svc.InitializeEscrow(ctx, "job", "customer"); err != nil {
		t.Fatal(err)
	}
	provider.checkout.Status = "HELD"
	if err := svc.ReleaseEscrow(ctx, "job", "customer"); !errors.Is(err, domain.ErrState) {
		t.Fatal("captured incomplete job")
	}
	repo.job.Status = "COMPLETED"
	for i := 0; i < 2; i++ {
		if err := svc.ReleaseEscrow(ctx, "job", "customer"); err != nil {
			t.Fatal(err)
		}
	}
	if provider.captured != 1 || repo.tx.Status != "RELEASED" {
		t.Fatal("duplicate or missing capture")
	}
}
func TestCancelledJobRefundRecoversFromFailure(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{}
	svc := NewPaymentService(repo, provider)
	ctx := context.Background()
	if _, err := svc.InitializeEscrow(ctx, "job", "customer"); err != nil {
		t.Fatal(err)
	}
	repo.job.Status = "CANCELLED"
	provider.checkout.Status = "HELD"
	provider.failure = errors.New("offline")
	if err := svc.Reconcile(ctx); err == nil {
		t.Fatal("expected failed reconciliation")
	}
	if repo.tx.Status == "REFUNDED" {
		t.Fatal("falsely marked refunded")
	}
	provider.failure = nil
	if err := svc.Reconcile(ctx); err != nil {
		t.Fatal(err)
	}
	if err := svc.Reconcile(ctx); err != nil {
		t.Fatal(err)
	}
	if repo.tx.Status != "REFUNDED" || provider.refunded != 1 {
		t.Fatal("refund was lost or repeated")
	}
}
func TestCashAndUnconfirmedCaptureRejected(t *testing.T) {
	repo := newMockPaymentRepo()
	provider := &mockProvider{}
	svc := NewPaymentService(repo, provider)
	ctx := context.Background()
	repo.job.PaymentMethod = "CASH"
	if _, err := svc.InitializeEscrow(ctx, "job", "customer"); !errors.Is(err, domain.ErrState) {
		t.Fatal("cash checkout allowed")
	}
	repo.job.PaymentMethod = "ONLINE"
	if _, err := svc.InitializeEscrow(ctx, "job", "customer"); err != nil {
		t.Fatal(err)
	}
	repo.job.Status = "COMPLETED"
	if err := svc.ReleaseEscrow(ctx, "job", "customer"); !errors.Is(err, domain.ErrState) {
		t.Fatal("unconfirmed payment captured")
	}
}
