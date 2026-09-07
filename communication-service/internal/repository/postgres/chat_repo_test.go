package postgres

import (
	"context"
	"github.com/service-marketplace/shared-contracts/pkg/testdb"
	"testing"
)

func TestChatMembershipAndSystemHistory(t *testing.T) {
	pool := testdb.Open(t)
	repo := NewChatRepository(pool)
	ctx := context.Background()
	for _, tt := range []struct {
		id   string
		want bool
	}{{testdb.Customer, true}, {testdb.Provider, true}, {testdb.Other, false}} {
		allowed, err := repo.IsParticipant(ctx, testdb.Job, tt.id)
		if err != nil || allowed != tt.want {
			t.Fatalf("participant %s=%v: %v", tt.id, allowed, err)
		}
	}
	testdb.Exec(t, pool, "UPDATE bids SET status='REJECTED'")
	allowed, err := repo.IsParticipant(ctx, testdb.Job, testdb.Provider)
	if err != nil || allowed {
		t.Fatal("rejected provider retained access")
	}
	testdb.Exec(t, pool, "INSERT INTO messages(job_id,content) VALUES($1,'JOB_CANCELLED')", testdb.Job)
	history, err := repo.GetMessagesByJob(ctx, testdb.Job)
	if err != nil {
		t.Fatal(err)
	}
	if len(history) != 1 || history[0].SenderID != "SYSTEM" {
		t.Fatal("system notification could not be read")
	}
}
