package service

import (
	"context"

	"github.com/service-marketplace/marketplace-service/internal/domain"
)

type mockMarketplaceRepo struct {
	jobs []domain.Job
	bids []domain.Bid
}

func newMockMarketplaceRepo() *mockMarketplaceRepo {
	return &mockMarketplaceRepo{
		jobs: []domain.Job{},
		bids: []domain.Bid{},
	}
}

func (m *mockMarketplaceRepo) GetJobs(ctx context.Context, category string, lat, lng, radius float64) ([]domain.Job, error) {
	return m.jobs, nil
}

func (m *mockMarketplaceRepo) CreateJob(ctx context.Context, job *domain.Job) error {
	m.jobs = append(m.jobs, *job)
	return nil
}

func (m *mockMarketplaceRepo) CreateBid(ctx context.Context, bid *domain.Bid) error {
	m.bids = append(m.bids, *bid)
	return nil
}

func (m *mockMarketplaceRepo) GetBidsByJobID(ctx context.Context, jobID string) ([]domain.Bid, error) {
	res := []domain.Bid{}
	for _, b := range m.bids {
		if b.JobID == jobID {
			res = append(res, b)
		}
	}
	return res, nil
}

func (m *mockMarketplaceRepo) AcceptBid(ctx context.Context, jobID, bidID string) error {
	return nil
}

func (m *mockMarketplaceRepo) CompleteJob(ctx context.Context, jobID, userID string, score int, comment string) error {
	return nil
}

func (m *mockMarketplaceRepo) UpdateJobStatus(ctx context.Context, jobID string, status string) error {
	for i, j := range m.jobs {
		if j.ID == jobID {
			m.jobs[i].Status = status
			return nil
		}
	}
	return nil
}

func (m *mockMarketplaceRepo) GetBidsByProviderID(ctx context.Context, providerID string) ([]domain.Bid, error) {
	res := []domain.Bid{}
	for _, b := range m.bids {
		if b.ProviderID == providerID {
			res = append(res, b)
		}
	}
	return res, nil
}

func (m *mockMarketplaceRepo) GetJobsForProvider(ctx context.Context, providerID string) ([]domain.Job, error) {
	return m.jobs, nil
}

func (m *mockMarketplaceRepo) GetCategoryInsights(ctx context.Context, category string) (float64, int, error) {
	return 100.0, 1, nil
}
