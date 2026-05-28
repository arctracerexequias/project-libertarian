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

func (s *dispatchService) GetPrivacyPartners(ctx context.Context, lat, lng float64, category string, radius float64) ([]domain.ProviderLocation, error) {
	providers, err := s.repo.FindNearbyProviders(ctx, lat, lng, category, radius)
	if err != nil {
		return nil, err
	}

	// Obfuscate locations
	for i := range providers {
		// Use ProviderID as a seed for stable obfuscation
		hash := 0
		for _, char := range providers[i].ProviderID {
			hash += int(char)
		}

		// Apply a deterministic shift between -0.002 and 0.002 (~200m)
		offsetLat := float64(hash%40-20) * 0.0001
		offsetLng := float64(hash%30-15) * 0.0001

		providers[i].Lat += offsetLat
		providers[i].Lng += offsetLng
		// Clear exact ProviderID for privacy
		providers[i].ProviderID = "PARTNER"
	}

	return providers, nil
}
