package postgres

import (
	"context"
	"errors"
	"github.com/service-marketplace/payment-service/internal/domain"
	"github.com/service-marketplace/shared-contracts/pkg/testdb"
	"testing"
	"time"
)

func TestReservationSurvivesProviderFailure(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewPaymentRepository(pool)
	ctx := context.Background()
	testdb.Exec(t, pool, "UPDATE bids SET status='ACCEPTED'")
	timeout := errors.New("provider timeout")
	err := repo.WithJob(ctx, testdb.Job, func(job domain.PaymentJob, store domain.PaymentStore) error {
		if job.AmountMinor != 50000 || job.CustomerID != testdb.Customer {
			t.Fatalf("wrong server payment details: %+v", job)
		}
		if err := store.Save(ctx, &domain.Transaction{ID: "00000000-0000-0000-0000-000000000031", JobID: testdb.Job, AmountMinor: job.AmountMinor, Currency: "PHP", Status: "PENDING", CreatedAt: time.Now()}); err != nil {
			return err
		}
		return timeout
	})
	if !errors.Is(err, timeout) {
		t.Fatal(err)
	}
	err = repo.WithJob(ctx, testdb.Job, func(_ domain.PaymentJob, store domain.PaymentStore) error {
		tx, err := store.Get(ctx)
		if err != nil {
			return err
		}
		if tx == nil || tx.Status != "PENDING" || tx.AmountMinor != 50000 {
			t.Fatalf("lost reservation: %+v", tx)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	ids, err := repo.ReconciliationJobs(ctx)
	if err != nil || len(ids) != 1 {
		t.Fatalf("reservation not queued: %v %v", ids, err)
	}
}
