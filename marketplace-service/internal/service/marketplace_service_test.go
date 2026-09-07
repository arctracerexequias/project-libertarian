package service

import (
	"context"
	"testing"

	"github.com/service-marketplace/marketplace-service/internal/domain"
)

func TestMarketplaceService_PostJob(t *testing.T) {
	repo := newMockMarketplaceRepo()
	svc := NewMarketplaceService(repo)

	req := domain.CreateJobRequest{
		Title:         "Fix my sink",
		Description:   "It's leaking everywhere",
		Category:      "home_repair",
		MaxBudget:     50.0,
		PaymentMethod: "CASH",
		IsEmergency:   true,
	}

	job, err := svc.PostJob(context.Background(), "user-123", req)
	if err != nil {
		t.Fatalf("Failed to post job: %v", err)
	}

	if job == nil || job.ID == "" {
		t.Fatal("Expected non-nil job with a valid ID")
	}

	jobs, _ := repo.GetJobs(context.Background(), "", 0, 0, 0)
	if len(jobs) != 1 {
		t.Fatalf("Expected 1 job, got %d", len(jobs))
	}
	if jobs[0].Title != req.Title {
		t.Errorf("Expected title %s, got %s", req.Title, jobs[0].Title)
	}
	if jobs[0].Status != "PUBLISHED" {
		t.Errorf("Expected status PUBLISHED, got %s", jobs[0].Status)
	}
	if jobs[0].PaymentMethod != "CASH" {
		t.Errorf("Expected payment method CASH, got %s", jobs[0].PaymentMethod)
	}
}

func TestMarketplaceService_CancelJobDelegatesDurableCancellation(t *testing.T) {
	repo := newMockMarketplaceRepo()
	svc := NewMarketplaceService(repo)
	if err := svc.CancelJob(context.Background(), "cash-job", "customer"); err != nil {
		t.Fatal(err)
	}
	if !repo.cancelled {
		t.Fatal("cancellation not persisted")
	}
}

func TestMarketplaceService_ListCustomerJobsIncludesAllStatuses(t *testing.T) {
	repo := newMockMarketplaceRepo()
	repo.jobs = []domain.Job{
		{ID: "published-job", CustomerID: "customer-1", Status: "PUBLISHED"},
		{ID: "completed-job", CustomerID: "customer-1", Status: "COMPLETED"},
		{ID: "other-customer-job", CustomerID: "customer-2", Status: "PUBLISHED"},
	}

	svc := NewMarketplaceService(repo)
	jobs, err := svc.ListCustomerJobs(context.Background(), "customer-1")
	if err != nil {
		t.Fatalf("Failed to list customer jobs: %v", err)
	}
	if len(jobs) != 2 {
		t.Fatalf("Expected 2 customer-owned jobs, got %d", len(jobs))
	}
	if jobs[1].Status != "COMPLETED" {
		t.Errorf("Expected completed job to remain in history, got %s", jobs[1].Status)
	}
}

func TestMarketplaceService_PlaceBid(t *testing.T) {
	repo := newMockMarketplaceRepo()
	svc := NewMarketplaceService(repo)

	req := domain.CreateBidRequest{
		Amount:        45.0,
		EstimatedTime: "1 hour",
		Message:       "I can fix it now",
	}

	bidID, err := svc.PlaceBid(context.Background(), "provider-456", "job-789", req)
	if err != nil {
		t.Fatalf("Failed to place bid: %v", err)
	}

	if bidID == "" {
		t.Fatal("Expected non-empty bid ID")
	}

	bids, _ := repo.GetBidsByJobID(context.Background(), "job-789")
	if len(bids) != 1 {
		t.Fatalf("Expected 1 bid, got %d", len(bids))
	}
	if bids[0].Amount != req.Amount {
		t.Errorf("Expected amount %f, got %f", req.Amount, bids[0].Amount)
	}
}

func TestInvalidBidAndRatingRejected(t *testing.T) {
	repo := newMockMarketplaceRepo()
	svc := NewMarketplaceService(repo)
	if _, err := svc.PlaceBid(context.Background(), "provider", "job", domain.CreateBidRequest{Amount: -1}); err == nil {
		t.Fatal("negative bid allowed")
	}
	if err := svc.MarkComplete(context.Background(), "job", "customer", domain.CompleteJobRequest{Score: 6}); err == nil {
		t.Fatal("invalid rating allowed")
	}
}
