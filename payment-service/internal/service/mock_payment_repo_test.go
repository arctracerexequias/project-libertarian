package service

import (
	"context"
	"github.com/service-marketplace/payment-service/internal/domain"
	"sync"
)

type mockPaymentRepo struct {
	mu  sync.Mutex
	job domain.PaymentJob
	tx  *domain.Transaction
}

func newMockPaymentRepo() *mockPaymentRepo {
	return &mockPaymentRepo{job: domain.PaymentJob{ID: "job", CustomerID: "customer", ProviderID: "provider", Status: "ACCEPTED", PaymentMethod: "ONLINE", AmountMinor: 125050}}
}
func (m *mockPaymentRepo) WithJob(ctx context.Context, id string, fn func(domain.PaymentJob, domain.PaymentStore) error) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return fn(m.job, m)
}
func (m *mockPaymentRepo) Get(context.Context) (*domain.Transaction, error) {
	if m.tx == nil {
		return nil, nil
	}
	copy := *m.tx
	return &copy, nil
}
func (m *mockPaymentRepo) Save(_ context.Context, t *domain.Transaction) error {
	copy := *t
	m.tx = &copy
	return nil
}
func (m *mockPaymentRepo) ReconciliationJobs(context.Context) ([]string, error) {
	return []string{m.job.ID}, nil
}

type mockProvider struct {
	created, captured, refunded int
	failure                     error
	checkout                    domain.Checkout
	keys                        []string
}

func (m *mockProvider) CreateCheckout(_ context.Context, t *domain.Transaction) (domain.Checkout, error) {
	m.created++
	m.keys = append(m.keys, t.ID)
	if m.failure != nil {
		return domain.Checkout{}, m.failure
	}
	m.checkout = domain.Checkout{ID: "cs_1", URL: "https://checkout.stripe.com/test", IntentID: "pi_1", Status: "PENDING", AmountMinor: t.AmountMinor, Currency: t.Currency}
	return m.checkout, nil
}
func (m *mockProvider) Checkout(context.Context, string) (domain.Checkout, error) {
	return m.checkout, m.failure
}
func (m *mockProvider) Capture(context.Context, string, string) error {
	if m.failure != nil {
		return m.failure
	}
	m.captured++
	m.checkout.Status = "RELEASED"
	return nil
}
func (m *mockProvider) Refund(context.Context, string, string, string) error {
	if m.failure != nil {
		return m.failure
	}
	m.refunded++
	return nil
}
