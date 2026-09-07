package postgres

import (
	"context"
	"github.com/service-marketplace/identity-service/internal/domain"
	"github.com/service-marketplace/shared-contracts/pkg/testdb"
	"sync"
	"testing"
)

func TestProfileUpdateDoesNotCreditWallet(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewUserRepository(pool)
	ctx := context.Background()
	for i := 0; i < 3; i++ {
		if err := repo.Update(ctx, &domain.User{ID: testdb.Provider, Role: "provider", FullName: "Updated", WalletBalance: 1000}); err != nil {
			t.Fatal(err)
		}
	}
	var balance float64
	if err := pool.QueryRow(ctx, "SELECT balance FROM provider_wallets WHERE provider_id=$1", testdb.Provider).Scan(&balance); err != nil {
		t.Fatal(err)
	}
	if balance != 1000 {
		t.Fatalf("profile update changed wallet to %v", balance)
	}
}
func TestBoostChargesExactlyOnceAndTogglePreservesExpiry(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewUserRepository(pool)
	ctx := context.Background()
	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := repo.SetCoverageBoost(ctx, testdb.Provider, 7); err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	var balance float64
	var count int
	var expiry string
	if err := pool.QueryRow(ctx, "SELECT balance FROM provider_wallets WHERE provider_id=$1", testdb.Provider).Scan(&balance); err != nil {
		t.Fatal(err)
	}
	pool.QueryRow(ctx, "SELECT COUNT(*) FROM wallet_transactions").Scan(&count)
	pool.QueryRow(ctx, "SELECT coverage_boost_expires_at::text FROM providers WHERE user_id=$1", testdb.Provider).Scan(&expiry)
	if balance != 801 || count != 1 {
		t.Fatalf("balance=%v, entries=%d", balance, count)
	}
	if err := repo.ToggleCoverageBoost(ctx, testdb.Provider, false); err != nil {
		t.Fatal(err)
	}
	if err := repo.ToggleCoverageBoost(ctx, testdb.Provider, true); err != nil {
		t.Fatal(err)
	}
	var after string
	pool.QueryRow(ctx, "SELECT coverage_boost_expires_at::text FROM providers WHERE user_id=$1", testdb.Provider).Scan(&after)
	if after != expiry {
		t.Fatal("toggle extended paid expiry")
	}
}
func TestInsufficientFundsDoNotActivateBoost(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewUserRepository(pool)
	ctx := context.Background()
	testdb.Exec(t, pool, "UPDATE provider_wallets SET balance=1")
	if err := repo.SetRoamBoost(ctx, testdb.Provider, 7); err == nil {
		t.Fatal("unpaid boost activated")
	}
	var active bool
	pool.QueryRow(ctx, "SELECT roam_boost_expires_at IS NOT NULL FROM providers WHERE user_id=$1", testdb.Provider).Scan(&active)
	if active {
		t.Fatal("expiry set without payment")
	}
}
