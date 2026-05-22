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
		Title:       "Fix my sink",
		Description: "It's leaking everywhere",
		Category:    "home_repair",
		MaxBudget:   50.0,
		IsEmergency: true,
	}

	jobID, err := svc.PostJob(context.Background(), "user-123", req)
	if err != nil {
		t.Fatalf("Failed to post job: %v", err)
	}

	if jobID == "" {
		t.Fatal("Expected non-empty job ID")
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
