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
	RecurrenceType     string     `json:"recurrence_type"` // ONCE, DAILY, WEEKLY, MONTHLY
	TotalOccurrences   int        `json:"total_occurrences"`
	ParentJobID        *string    `json:"parent_job_id,omitempty"`
	ScheduledAt        *time.Time `json:"scheduled_at"`
	CreatedAt          time.Time  `json:"created_at"`
}

type Bid struct {
	ID               string    `json:"id"`
	JobID            string    `json:"job_id"`
	ProviderID       string    `json:"provider_id"`
	Amount           float64   `json:"amount"`
	EstimatedTime    string    `json:"estimated_time"`
	Message          string    `json:"message"`
	Status           string    `json:"status"`
	DeclineReason    string    `json:"decline_reason,omitempty"`
	CounterAmount    float64   `json:"counter_amount,omitempty"`
	CounterBy        string    `json:"counter_by,omitempty"`
	ProviderRating   float64   `json:"provider_rating"`
	ProviderVerified bool      `json:"provider_verified"`
	ProviderName     string    `json:"provider_name"`
	CreatedAt        time.Time `json:"created_at"`
}

type CreateJobRequest struct {
	Title            string     `json:"title" binding:"required"`
	Description      string     `json:"description" binding:"required"`
	Category         string     `json:"category" binding:"required"`
	MaxBudget        float64    `json:"max_budget"`
	IsEmergency      bool       `json:"is_emergency"`
	Lat              float64    `json:"lat"`
	Lng              float64    `json:"lng"`
	RecurrenceType   string     `json:"recurrence_type"`
	TotalOccurrences int        `json:"total_occurrences"`
	ParentJobID      *string    `json:"parent_job_id"`
	ScheduledAt      *time.Time `json:"scheduled_at"`
}

type CreateBidRequest struct {
	Amount        float64 `json:"amount" binding:"required"`
	EstimatedTime string  `json:"estimated_time" binding:"required"`
	Message       string  `json:"message"`
}

type CounterBidRequest struct {
	Amount float64 `json:"amount" binding:"required"`
	Reason string  `json:"reason"`
}

type CompleteJobRequest struct {
	Score   int    `json:"score" binding:"required"`
	Comment string `json:"comment"`
}

type MarketplaceRepository interface {
	GetJobs(ctx context.Context, category string, lat, lng, radius float64) ([]Job, error)
	GetJobByID(ctx context.Context, id string) (*Job, error)
	CreateJob(ctx context.Context, job *Job) error
	CreateBid(ctx context.Context, bid *Bid) error
	GetBidsByJobID(ctx context.Context, jobID string) ([]Bid, error)
	AcceptBid(ctx context.Context, jobID, bidID string) error
	RejectBid(ctx context.Context, jobID, bidID string, reason string) error
	CounterBid(ctx context.Context, bidID string, userID string, amount float64, reason string) error
	CompleteJob(ctx context.Context, jobID, userID string, score int, comment string) error
	GetBidsByProviderID(ctx context.Context, providerID string) ([]Bid, error)
	GetJobsForProvider(ctx context.Context, providerID string) ([]Job, error)
	GetCategoryInsights(ctx context.Context, category string) (float64, int, error)
	UpdateJobStatus(ctx context.Context, jobID string, status string) error
	CancelJob(ctx context.Context, jobID string, userID string) error
}

type MarketplaceService interface {
	ListJobs(ctx context.Context, category string, lat, lng, radius float64) ([]Job, error)
	GetJob(ctx context.Context, id string) (*Job, error)
	PostJob(ctx context.Context, customerID string, req CreateJobRequest) (*Job, error)
	PlaceBid(ctx context.Context, providerID, jobID string, req CreateBidRequest) (string, error)
	ListBids(ctx context.Context, jobID string) ([]Bid, error)
	AcceptOffer(ctx context.Context, jobID, bidID string) error
	RejectOffer(ctx context.Context, jobID, bidID string, reason string) error
	CounterOffer(ctx context.Context, bidID string, userID string, req CounterBidRequest) error
	MarkComplete(ctx context.Context, jobID, userID string, req CompleteJobRequest) error
	ListProviderBids(ctx context.Context, providerID string) ([]Bid, error)
	ListProviderJobs(ctx context.Context, providerID string) ([]Job, error)
	GetInsights(ctx context.Context, category string) (float64, int, error)
	UpdateJobStatus(ctx context.Context, jobID string, status string) error
	CancelJob(ctx context.Context, jobID string, userID string) error
}
