package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
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
	job := &domain.Job{
		ID:               uuid.New().String(),
		CustomerID:       customerID,
		Title:            req.Title,
		Description:      req.Description,
		Category:         req.Category,
		Status:           "PUBLISHED",
		MaxBudget:        req.MaxBudget,
		IsEmergency:      req.IsEmergency,
		Lat:              req.Lat,
		Lng:              req.Lng,
		RecurrenceType:   req.RecurrenceType,
		TotalOccurrences: req.TotalOccurrences,
		ParentJobID:      req.ParentJobID,
		ScheduledAt:      req.ScheduledAt,
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
	err := s.repo.CreateJob(ctx, job)
	return job, err
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

func (s *marketplaceService) RejectOffer(ctx context.Context, jobID, bidID string, reason string) error {
	return s.repo.RejectBid(ctx, jobID, bidID, reason)
}

func (s *marketplaceService) CounterOffer(ctx context.Context, bidID string, userID string, req domain.CounterBidRequest) error {
	return s.repo.CounterBid(ctx, bidID, userID, req.Amount, req.Reason)
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

func (s *marketplaceService) CancelJob(ctx context.Context, jobID string, userID string) error {
	err := s.repo.CancelJob(ctx, jobID, userID)
	if err != nil {
		return err
	}

	// Trigger refund in payment service
	paymentServiceURL := os.Getenv("PAYMENT_SERVICE_URL")
	if paymentServiceURL == "" {
		paymentServiceURL = "http://payment-service:8084"
	}

	payload := map[string]string{"job_id": jobID}
	jsonPayload, _ := json.Marshal(payload)

	req, _ := http.NewRequestWithContext(ctx, "POST", fmt.Sprintf("%s/escrow/refund", paymentServiceURL), bytes.NewBuffer(jsonPayload))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		// Log error but don't fail job cancellation if payment service is down
		// In production, we'd use a retry mechanism or an event bus
		fmt.Printf("Warning: Failed to trigger refund for job %s: %v\n", jobID, err)
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("Warning: Payment service returned status %d for refund of job %s\n", resp.StatusCode, jobID)
	}

	// Notify communication service
	commServiceURL := os.Getenv("COMMUNICATION_SERVICE_URL")
	if commServiceURL == "" {
		commServiceURL = "http://communication-service:8083"
	}

	commPayload := map[string]string{
		"job_id":  jobID,
		"content": "JOB_CANCELLED",
	}
	jsonCommPayload, _ := json.Marshal(commPayload)

	reqComm, _ := http.NewRequestWithContext(ctx, "POST", fmt.Sprintf("%s/chat/system", commServiceURL), bytes.NewBuffer(jsonCommPayload))
	reqComm.Header.Set("Content-Type", "application/json")

	respComm, err := client.Do(reqComm)
	if err != nil {
		fmt.Printf("Warning: Failed to notify communication service for job %s: %v\n", jobID, err)
		return nil
	}
	defer respComm.Body.Close()

	return nil
}
