package service

import (
	"context"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/service-marketplace/marketplace-service/internal/domain"
)

type marketplaceService struct {
	repo domain.MarketplaceRepository
}

func NewMarketplaceService(repo domain.MarketplaceRepository) domain.MarketplaceService {
	return &marketplaceService{repo: repo}
}

func (s *marketplaceService) ListJobs(ctx context.Context, category string, lat, lng, radius float64) ([]domain.Job, error) {
	return s.repo.GetJobs(ctx, category, lat, lng, radius)
}

func (s *marketplaceService) GetJob(ctx context.Context, id string) (*domain.Job, error) {
	return s.repo.GetJobByID(ctx, id)
}

func (s *marketplaceService) PostJob(ctx context.Context, customerID string, req domain.CreateJobRequest) (*domain.Job, error) {
	if strings.TrimSpace(req.Title) == "" || strings.TrimSpace(req.Description) == "" || req.MaxBudget <= 0 || math.IsNaN(req.MaxBudget) || math.IsInf(req.MaxBudget, 0) {
		return nil, fmt.Errorf("%w: enter a title, description and positive offer", domain.ErrInvalidBooking)
	}
	id := uuid.New().String()
	if req.RequestID != "" {
		if _, err := uuid.Parse(req.RequestID); err != nil {
			return nil, fmt.Errorf("%w: invalid request ID", domain.ErrInvalidBooking)
		}
		id = uuid.NewSHA1(uuid.NameSpaceOID, []byte(customerID+":"+req.RequestID)).String()
		// A retry after a lost response returns the original persisted job.
		if existing, err := s.repo.GetJobByID(ctx, id); err == nil {
			return existing, nil
		}
	}
	start := req.ScheduledAt
	if req.IsEmergency {
		now := time.Now()
		start = &now
	}
	if err := req.Booking.Validate(start, req.MaxBudget); err != nil {
		return nil, fmt.Errorf("%w: %s", domain.ErrInvalidBooking, err)
	}
	if req.Booking != nil && !req.IsEmergency && (start == nil || start.Before(time.Now().Add(-time.Minute))) {
		return nil, fmt.Errorf("%w: choose a future service date", domain.ErrInvalidBooking)
	}
	job := &domain.Job{
		ID:               id,
		Booking:          req.Booking,
		CustomerID:       customerID,
		Title:            req.Title,
		Description:      req.Description,
		Category:         req.Category,
		Status:           "PUBLISHED",
		MaxBudget:        req.MaxBudget,
		PaymentMethod:    req.PaymentMethod,
		IsEmergency:      req.IsEmergency,
		Lat:              req.Lat,
		Lng:              req.Lng,
		RecurrenceType:   req.RecurrenceType,
		TotalOccurrences: req.TotalOccurrences,
		ParentJobID:      req.ParentJobID,
		ScheduledAt:      start,
		CreatedAt:        time.Now(),
	}
	if job.ParentJobID != nil && *job.ParentJobID == "" {
		job.ParentJobID = nil
	}
	if job.TotalOccurrences == 0 {
		job.TotalOccurrences = 1
	}
	if job.RecurrenceType == "" {
		job.RecurrenceType = "ONCE"
	}
	if job.PaymentMethod == "" {
		job.PaymentMethod = "ONLINE"
	}
	err := s.repo.CreateJob(ctx, job)
	if err == nil && req.RequestID != "" {
		return s.repo.GetJobByID(ctx, id)
	}
	return job, err
}

func (s *marketplaceService) PlaceBid(ctx context.Context, providerID, jobID string, req domain.CreateBidRequest) (string, error) {
	if req.Amount <= 0 {
		return "", fmt.Errorf("bid amount must be positive")
	}
	bidID := uuid.New().String()
	bid := &domain.Bid{
		ID:            bidID,
		JobID:         jobID,
		ProviderID:    providerID,
		Amount:        req.Amount,
		EstimatedTime: req.EstimatedTime,
		Message:       req.Message,
		Status:        "PENDING",
	}
	err := s.repo.CreateBid(ctx, bid)
	return bidID, err
}

func (s *marketplaceService) ListBids(ctx context.Context, jobID string) ([]domain.Bid, error) {
	return s.repo.GetBidsByJobID(ctx, jobID)
}

func (s *marketplaceService) AcceptOffer(ctx context.Context, jobID, bidID, userID string) error {
	return s.repo.AcceptBid(ctx, jobID, bidID, userID)
}

func (s *marketplaceService) RejectOffer(ctx context.Context, jobID, bidID, userID string, reason string) error {
	return s.repo.RejectBid(ctx, jobID, bidID, userID, reason)
}

func (s *marketplaceService) CounterOffer(ctx context.Context, bidID string, userID string, req domain.CounterBidRequest) error {
	if req.Amount <= 0 {
		return fmt.Errorf("counter amount must be positive")
	}
	return s.repo.CounterBid(ctx, bidID, userID, req.Amount, req.Reason)
}

func (s *marketplaceService) MarkComplete(ctx context.Context, jobID, userID string, req domain.CompleteJobRequest) error {
	if req.Score < 1 || req.Score > 5 {
		return fmt.Errorf("rating must be between 1 and 5")
	}
	return s.repo.CompleteJob(ctx, jobID, userID, req.Score, req.Comment)
}

func (s *marketplaceService) ListProviderBids(ctx context.Context, providerID string) ([]domain.Bid, error) {
	return s.repo.GetBidsByProviderID(ctx, providerID)
}

func (s *marketplaceService) ListProviderJobs(ctx context.Context, providerID string) ([]domain.Job, error) {
	return s.repo.GetJobsForProvider(ctx, providerID)
}

func (s *marketplaceService) ListCustomerJobs(ctx context.Context, customerID string) ([]domain.Job, error) {
	return s.repo.GetJobsForCustomer(ctx, customerID)
}

func (s *marketplaceService) GetInsights(ctx context.Context, category string) (float64, int, error) {
	return s.repo.GetCategoryInsights(ctx, category)
}

func (s *marketplaceService) UpdateJobStatus(ctx context.Context, jobID, userID string, status string) error {
	return s.repo.UpdateJobStatus(ctx, jobID, userID, status)
}

func (s *marketplaceService) CancelJob(ctx context.Context, jobID string, userID string) error {
	return s.repo.CancelJob(ctx, jobID, userID)
}
