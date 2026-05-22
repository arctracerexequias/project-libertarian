package service

import (
	"context"

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

func (s *marketplaceService) PostJob(ctx context.Context, customerID string, req domain.CreateJobRequest) (string, error) {
	jobID := uuid.New().String()
	job := &domain.Job{
		ID:          jobID,
		CustomerID:  customerID,
		Title:       req.Title,
		Description: req.Description,
		Category:    req.Category,
		Status:      "PUBLISHED",
		MaxBudget:   req.MaxBudget,
		IsEmergency: req.IsEmergency,
		Lat:         req.Lat,
		Lng:         req.Lng,
	}
	err := s.repo.CreateJob(ctx, job)
	return jobID, err
}

func (s *marketplaceService) PlaceBid(ctx context.Context, providerID, jobID string, req domain.CreateBidRequest) (string, error) {
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

func (s *marketplaceService) AcceptOffer(ctx context.Context, jobID, bidID string) error {
	return s.repo.AcceptBid(ctx, jobID, bidID)
}

func (s *marketplaceService) MarkComplete(ctx context.Context, jobID, userID string, req domain.CompleteJobRequest) error {
	return s.repo.CompleteJob(ctx, jobID, userID, req.Score, req.Comment)
}

func (s *marketplaceService) ListProviderBids(ctx context.Context, providerID string) ([]domain.Bid, error) {
	return s.repo.GetBidsByProviderID(ctx, providerID)
}

func (s *marketplaceService) ListProviderJobs(ctx context.Context, providerID string) ([]domain.Job, error) {
	return s.repo.GetJobsForProvider(ctx, providerID)
}

func (s *marketplaceService) GetInsights(ctx context.Context, category string) (float64, int, error) {
	return s.repo.GetCategoryInsights(ctx, category)
}

func (s *marketplaceService) UpdateJobStatus(ctx context.Context, jobID string, status string) error {
	return s.repo.UpdateJobStatus(ctx, jobID, status)
}
