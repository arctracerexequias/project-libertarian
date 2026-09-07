package domain

import (
	"context"
	"errors"
	"time"
)

var ErrForbidden = errors.New("not permitted to access this payment")
var ErrState = errors.New("payment action is not allowed in the current state")

type Transaction struct {
	ID             string    `json:"id"`
	JobID          string    `json:"job_id"`
	AmountMinor    int64     `json:"amount_minor"`
	Currency       string    `json:"currency"`
	Status         string    `json:"status"`
	StripeIntentID string    `json:"-"`
	CheckoutID     string    `json:"-"`
	CheckoutURL    string    `json:"checkout_url,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
}
type PaymentJob struct {
	ID, CustomerID, ProviderID, Status, PaymentMethod string
	AmountMinor                                       int64
}
type PaymentStore interface {
	Get(context.Context) (*Transaction, error)
	Save(context.Context, *Transaction) error
}
type PaymentRepository interface {
	// WithJob serializes payment operations with booking mutations using a job row lock.
	// Successful local writes commit even on provider errors to preserve retry identity.
	WithJob(context.Context, string, func(PaymentJob, PaymentStore) error) error
	ReconciliationJobs(context.Context) ([]string, error)
}
type Checkout struct {
	ID, URL, IntentID, Status string
	AmountMinor               int64
	Currency                  string
}
type PaymentProvider interface {
	CreateCheckout(context.Context, *Transaction) (Checkout, error)
	Checkout(context.Context, string) (Checkout, error)
	Capture(context.Context, string, string) error
	Refund(context.Context, string, string, string) error
}
type PaymentService interface {
	InitializeEscrow(context.Context, string, string) (*Transaction, error)
	GetEscrow(context.Context, string, string) (*Transaction, error)
	ReleaseEscrow(context.Context, string, string) error
	RefundEscrow(context.Context, string, string) error
	Reconcile(context.Context) error
}
