package postgres

import (
	"context"
	"encoding/base64"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/service-marketplace/marketplace-service/internal/domain"
	"github.com/service-marketplace/marketplace-service/internal/service"
	"github.com/service-marketplace/shared-contracts/pkg/testdb"
)

func TestBookingRoundTripAndRetry(t *testing.T) {
	pool := testdb.Open(t)
	// Add spatial booking columns to the shared minimal relational fixture.
	testdb.Exec(t, pool, `ALTER TABLE jobs
 ADD COLUMN title text NOT NULL DEFAULT '', ADD COLUMN description text NOT NULL DEFAULT '',
 ADD COLUMN category text NOT NULL DEFAULT '', ADD COLUMN max_budget numeric(12,2) NOT NULL DEFAULT 0,
 ADD COLUMN is_emergency boolean NOT NULL DEFAULT false,
 ADD COLUMN location geography(POINT,4326) NOT NULL DEFAULT ST_SetSRID(ST_MakePoint(0,0),4326)::geography,
 ADD COLUMN recurrence_type text NOT NULL DEFAULT 'ONCE', ADD COLUMN total_occurrences int NOT NULL DEFAULT 1,
 ADD COLUMN parent_job_id uuid, ADD COLUMN scheduled_at timestamptz, ADD COLUMN created_at timestamptz NOT NULL DEFAULT now()`)
	repo := NewMarketplaceRepository(pool)
	svc := service.NewMarketplaceService(repo)
	ctx := context.Background()
	end := time.Now().Add(3 * time.Hour)
	photo := "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="
	req := domain.CreateJobRequest{Title: "Garden work", Description: "Prune and clear weeds", Category: "Personal Care > Landscaping", MaxBudget: 1200, PaymentMethod: "CASH", IsEmergency: true, RequestID: uuid.NewString(), Booking: &domain.Booking{Area: "Makati", Workers: 2, UnitOffer: 600, EndAt: &end, Answers: map[string]string{"Tasks": "Pruning"}, Private: &domain.PrivateBooking{Address: "Private unit", Contact: "09171234567", Answers: map[string]string{"Intake": "Private notes"}, Photos: []domain.BookingPhoto{{Name: "garden.png", Data: photo}}}}}
	first, err := svc.PostJob(ctx, testdb.Customer, req)
	if err != nil {
		t.Fatal(err)
	}
	retry, err := svc.PostJob(ctx, testdb.Customer, req)
	if err != nil {
		t.Fatal(err)
	}
	if first.ID != retry.ID {
		t.Fatal("duplicate on retry")
	}
	stored, err := repo.GetJobByID(ctx, first.ID)
	if err != nil {
		t.Fatal(err)
	}
	if stored.Booking == nil || stored.Booking.Private == nil {
		t.Fatal("missing private booking")
	}
	if stored.Booking.Private.Address != "Private unit" || stored.Booking.Private.Photos[0].Data != photo || stored.Booking.EndAt == nil || stored.Booking.Answers["Tasks"] != "Pruning" {
		t.Fatal("booking did not round trip")
	}
	if _, err := base64.StdEncoding.DecodeString(stored.Booking.Private.Photos[0].Data); err != nil {
		t.Fatal(err)
	}
	jobs, err := repo.GetJobsForCustomer(ctx, testdb.Customer)
	if err != nil {
		t.Fatal(err)
	}
	if len(jobs) != 2 {
		t.Fatalf("expected original fixture and one booking, got %d", len(jobs))
	}
	for _, job := range jobs {
		if job.Booking != nil && job.Booking.Private != nil {
			t.Fatal("list unnecessarily fetched private photos")
		}
	}
	if _, err := repo.GetJobs(ctx, "", 0, 0, 0); err != nil {
		t.Fatal(err)
	}
	bid := domain.Bid{ID: uuid.NewString(), JobID: first.ID, ProviderID: testdb.Provider, Amount: 1200, EstimatedTime: "3 hours", Status: "PENDING"}
	if err := repo.CreateBid(ctx, &bid); err != nil {
		t.Fatal(err)
	}
	if err := repo.AcceptBid(ctx, first.ID, bid.ID, testdb.Customer); err != nil {
		t.Fatal(err)
	}
	stored, err = repo.GetJobByID(ctx, first.ID)
	if err != nil {
		t.Fatal(err)
	}
	if stored.AcceptedProviderID != testdb.Provider || stored.ForViewer(testdb.Provider).Booking.Private == nil {
		t.Fatal("accepted provider lost private details")
	}
	if stored.ForViewer(testdb.Other).Booking.Private != nil {
		t.Fatal("unassigned provider saw private details")
	}
	if _, err := repo.GetJobsForProvider(ctx, testdb.Provider); err != nil {
		t.Fatal(err)
	}
}
