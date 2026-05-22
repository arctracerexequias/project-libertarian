package service

import (
	"context"
	"testing"

	"github.com/service-marketplace/dispatch-service/internal/domain"
)

func TestDispatchService_UpdateProviderLocation(t *testing.T) {
	repo := newMockDispatchRepo()
	svc := NewDispatchService(repo)

	err := svc.UpdateProviderLocation(context.Background(), "provider-1", 1.23, 4.56)
	if err != nil {
		t.Fatalf("Failed to update location: %v", err)
	}

	loc, ok := repo.locations["provider-1"]
	if !ok {
		t.Fatal("Location not found in repo")
	}
	if loc.Lat != 1.23 || loc.Lng != 4.56 {
		t.Errorf("Expected 1.23, 4.56, got %f, %f", loc.Lat, loc.Lng)
	}
}

func TestDispatchService_DispatchJob(t *testing.T) {
	repo := newMockDispatchRepo()
	svc := NewDispatchService(repo)

	req := domain.DispatchRequest{
		JobID:    "job-123",
		Lat:      1.23,
		Lng:      4.56,
		Category: "home_repair",
	}

	providers, err := svc.DispatchJob(context.Background(), req)
	if err != nil {
		t.Fatalf("Failed to dispatch: %v", err)
	}

	if len(providers) != 2 {
		t.Fatalf("Expected 2 providers, got %d", len(providers))
	}
}
