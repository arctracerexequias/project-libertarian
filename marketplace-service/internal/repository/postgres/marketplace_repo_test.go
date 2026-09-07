package postgres

import (
	"context"
	"github.com/service-marketplace/shared-contracts/pkg/testdb"
	"sync"
	"sync/atomic"
	"testing"
)

func TestBidOwnershipAndRelationship(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewMarketplaceRepository(pool)
	ctx := context.Background()
	if err := repo.AcceptBid(ctx, testdb.Job, testdb.Bid, testdb.Other); err == nil {
		t.Fatal("outsider accepted bid")
	}
	otherJob := "00000000-0000-0000-0000-000000000012"
	testdb.Exec(t, pool, "INSERT INTO jobs(id,customer_id,status) VALUES($1,$2,'PUBLISHED')", otherJob, testdb.Customer)
	if err := repo.AcceptBid(ctx, otherJob, testdb.Bid, testdb.Customer); err == nil {
		t.Fatal("accepted bid from another job")
	}
	if err := repo.RejectBid(ctx, testdb.Job, testdb.Bid, testdb.Other, "no"); err == nil {
		t.Fatal("outsider rejected bid")
	}
	if err := repo.CounterBid(ctx, testdb.Bid, testdb.Other, 100, "counter"); err == nil {
		t.Fatal("outsider countered bid")
	}
}
func TestConcurrentAcceptanceHasOneWinner(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewMarketplaceRepository(pool)
	ctx := context.Background()
	second := "00000000-0000-0000-0000-000000000022"
	testdb.Exec(t, pool, "INSERT INTO bids(id,job_id,provider_id,amount,status) VALUES($1,$2,$3,600,'PENDING')", second, testdb.Job, testdb.Other)
	var wg sync.WaitGroup
	var successes atomic.Int32
	for _, bid := range []string{testdb.Bid, second} {
		wg.Add(1)
		go func(id string) {
			defer wg.Done()
			if repo.AcceptBid(ctx, testdb.Job, id, testdb.Customer) == nil {
				successes.Add(1)
			}
		}(bid)
	}
	wg.Wait()
	var accepted int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM bids WHERE status='ACCEPTED'").Scan(&accepted)
	if successes.Load() != 1 || accepted != 1 {
		t.Fatalf("successful accepts=%d; accepted bids=%d", successes.Load(), accepted)
	}
}
func TestCompletionRollsBackInvalidRatingAndRejectsOutsider(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewMarketplaceRepository(pool)
	ctx := context.Background()
	if err := repo.AcceptBid(ctx, testdb.Job, testdb.Bid, testdb.Customer); err != nil {
		t.Fatal(err)
	}
	if err := repo.UpdateJobStatus(ctx, testdb.Job, testdb.Other, "EN_ROUTE"); err == nil {
		t.Fatal("outsider changed status")
	}
	if err := repo.UpdateJobStatus(ctx, testdb.Job, testdb.Provider, "COMPLETED"); err == nil {
		t.Fatal("skipped lifecycle")
	}
	if err := repo.UpdateJobStatus(ctx, testdb.Job, testdb.Provider, "EN_ROUTE"); err != nil {
		t.Fatal(err)
	}
	if err := repo.UpdateJobStatus(ctx, testdb.Job, testdb.Provider, "IN_PROGRESS"); err != nil {
		t.Fatal(err)
	}
	if err := repo.CompleteJob(ctx, testdb.Job, testdb.Other, 5, "great"); err == nil {
		t.Fatal("outsider completed job")
	}
	if err := repo.CompleteJob(ctx, testdb.Job, testdb.Customer, 6, "invalid"); err == nil {
		t.Fatal("invalid rating accepted")
	}
	var status string
	pool.QueryRow(ctx, "SELECT status FROM jobs WHERE id=$1", testdb.Job).Scan(&status)
	if status != "IN_PROGRESS" {
		t.Fatal("partial completion committed")
	}
	for i := 0; i < 2; i++ {
		if err := repo.CompleteJob(ctx, testdb.Job, testdb.Customer, 5, "great"); err != nil {
			t.Fatal(err)
		}
	}
	var count int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM ratings").Scan(&count)
	if count != 1 {
		t.Fatal("duplicate rating")
	}
}
func TestCancellationPersistsSystemMessageOnce(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewMarketplaceRepository(pool)
	ctx := context.Background()
	if err := repo.CancelJob(ctx, testdb.Job, testdb.Other); err == nil {
		t.Fatal("outsider cancelled")
	}
	for i := 0; i < 2; i++ {
		if err := repo.CancelJob(ctx, testdb.Job, testdb.Customer); err != nil {
			t.Fatal(err)
		}
	}
	var count int
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM messages WHERE sender_id IS NULL AND content='JOB_CANCELLED'").Scan(&count)
	if count != 1 {
		t.Fatal("cancellation notification lost or duplicated")
	}
}
