package domain

import (
	"context"
	"time"
)

type Job struct {
	ID                 string    `json:"id"`
	CustomerID         string    `json:"customer_id"`
	Title              string    `json:"title"`
	Description        string    `json:"description"`
	Category           string    `json:"category"`
	Status             string    `json:"status"`
	MaxBudget          float64   `json:"max_budget"`
	IsEmergency        bool      `json:"is_emergency"`
	Lat                float64   `json:"lat"`
	Lng                float64   `json:"lng"`
	AcceptedProviderID string    `json:"accepted_provider_id,omitempty"`
	AcceptedBidAmount  float64   `json:"accepted_bid_amount,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
}

type Bid struct {
	ID             string    `json:"id"`
	JobID          string    `json:"job_id"`
	ProviderID     string    `json:"provider_id"`
	Amount         float64   `json:"amount"`
	EstimatedTime  string    `json:"estimated_time"`
	Message        string    `json:"message"`
	Status         string    `json:"status"`
	ProviderRating   float64   `json:"provider_rating"`
	ProviderVerified bool      `json:"provider_verified"`
	CreatedAt        time.Time `json:"created_at"`
}

type CreateJobRequest struct {
	Title       string  `json:"title" binding:"required"`
	Description string  `json:"description" binding:"required"`
	Category    string  `json:"category" binding:"required"`
	MaxBudget   float64 `json:"max_budget"`
	IsEmergency bool    `json:"is_emergency"`
	Lat         float64 `json:"lat"`
	Lng         float64 `json:"lng"`
}

type CreateBidRequest struct {
	Amount        float64 `json:"amount" binding:"required"`
	EstimatedTime string  `json:"estimated_time" binding:"required"`
	Message       string  `json:"message"`
}

type CompleteJobRequest struct {
	Score   int    `json:"score" binding:"required"`
	Comment string `json:"comment"`
}

type MarketplaceRepository interface {
	GetJobs(ctx context.Context, category string, lat, lng, radius float64) ([]Job, error)
	CreateJob(ctx context.Context, job *Job) error
	CreateBid(ctx context.Context, bid *Bid) error
	GetBidsByJobID(ctx context.Context, jobID string) ([]Bid, error)
	AcceptBid(ctx context.Context, jobID, bidID string) error
	CompleteJob(ctx context.Context, jobID, userID string, score int, comment string) error
	GetBidsByProviderID(ctx context.Context, providerID string) ([]Bid, error)
	GetJobsForProvider(ctx context.Context, providerID string) ([]Job, error)
	GetCategoryInsights(ctx context.Context, category string) (float64, int, error)
	UpdateJobStatus(ctx context.Context, jobID string, status string) error
}

type MarketplaceService interface {
	ListJobs(ctx context.Context, category string, lat, lng, radius float64) ([]Job, error)
	PostJob(ctx context.Context, customerID string, req CreateJobRequest) (string, error)
	PlaceBid(ctx context.Context, providerID, jobID string, req CreateBidRequest) (string, error)
	ListBids(ctx context.Context, jobID string) ([]Bid, error)
	AcceptOffer(ctx context.Context, jobID, bidID string) error
	MarkComplete(ctx context.Context, jobID, userID string, req CompleteJobRequest) error
	ListProviderBids(ctx context.Context, providerID string) ([]Bid, error)
	ListProviderJobs(ctx context.Context, providerID string) ([]Job, error)
	GetInsights(ctx context.Context, category string) (float64, int, error)
	UpdateJobStatus(ctx context.Context, jobID string, status string) error
}
