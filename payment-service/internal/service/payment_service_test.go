package service

import (
	"context"
	"os"
	"testing"

	"github.com/service-marketplace/payment-service/internal/domain"
)

func TestPaymentService_InitializeEscrow(t *testing.T) {
	os.Setenv("STRIPE_SECRET_KEY", "sk_test_123")
	repo := newMockPaymentRepo()
	svc := NewPaymentService(repo)
	_ = svc
}

func TestPaymentService_ReleaseEscrow(t *testing.T) {
	repo := newMockPaymentRepo()
	svc := NewPaymentService(repo)

	jobID := "job-123"
	repo.transactions[jobID] = &domain.Transaction{JobID: jobID, Status: "HELD"}

	err := svc.ReleaseEscrow(context.Background(), jobID)
	if err != nil {
		t.Fatalf("Failed to release escrow: %v", err)
	}

	if repo.transactions[jobID].Status != "RELEASED" {
		t.Errorf("Expected status RELEASED, got %s", repo.transactions[jobID].Status)
	}
}
