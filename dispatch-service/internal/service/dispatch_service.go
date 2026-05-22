package service

import (
	"context"
	"time"

	"github.com/service-marketplace/dispatch-service/internal/domain"
)

type dispatchService struct {
	repo domain.DispatchRepository
}

func NewDispatchService(repo domain.DispatchRepository) domain.DispatchService {
	return &dispatchService{repo: repo}
}

func (s *dispatchService) UpdateProviderLocation(ctx context.Context, providerID string, lat, lng float64) error {
	loc := &domain.ProviderLocation{
		ProviderID: providerID,
		Lat:        lat,
		Lng:        lng,
		UpdatedAt:  time.Now(),
	}
	return s.repo.UpdateLocation(ctx, loc)
}

func (s *dispatchService) DispatchJob(ctx context.Context, req domain.DispatchRequest) ([]domain.ProviderLocation, error) {
	if req.Radius == 0 {
		req.Radius = 5000 // Default 5km
	}
	return s.repo.FindNearbyProviders(ctx, req.Lat, req.Lng, req.Category, req.Radius)
}
