package domain

import (
	"context"
	"time"
)

type ProviderLocation struct {
	ProviderID string    `json:"provider_id"`
	Lat        float64   `json:"lat"`
	Lng        float64   `json:"lng"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type DispatchRequest struct {
	JobID    string  `json:"job_id"`
	Lat      float64 `json:"lat"`
	Lng      float64 `json:"lng"`
	Category string  `json:"category"`
	Radius   float64 `json:"radius"` // In meters
}

type DispatchRepository interface {
	UpdateLocation(ctx context.Context, loc *ProviderLocation) error
	FindNearbyProviders(ctx context.Context, lat, lng float64, category string, radius float64) ([]ProviderLocation, error)
}

type DispatchService interface {
	UpdateProviderLocation(ctx context.Context, providerID string, lat, lng float64) error
	DispatchJob(ctx context.Context, req DispatchRequest) ([]ProviderLocation, error)
}
