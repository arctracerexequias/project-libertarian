package service

import (
	"context"

	"github.com/service-marketplace/dispatch-service/internal/domain"
)

type mockDispatchRepo struct {
	locations map[string]*domain.ProviderLocation
}

func newMockDispatchRepo() *mockDispatchRepo {
	return &mockDispatchRepo{locations: make(map[string]*domain.ProviderLocation)}
}

func (m *mockDispatchRepo) UpdateLocation(ctx context.Context, loc *domain.ProviderLocation) error {
	m.locations[loc.ProviderID] = loc
	return nil
}

func (m *mockDispatchRepo) FindNearbyProviders(ctx context.Context, lat, lng float64, category string, radius float64) ([]domain.ProviderLocation, error) {
	return []domain.ProviderLocation{
		{ProviderID: "provider-1", Lat: lat + 0.01, Lng: lng + 0.01},
		{ProviderID: "provider-2", Lat: lat - 0.01, Lng: lng - 0.01},
	}, nil
}
