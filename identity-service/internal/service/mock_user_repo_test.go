package service

import (
	"context"

	"github.com/service-marketplace/identity-service/internal/domain"
)

type mockUserRepo struct {
	users map[string]*domain.User
}

func newMockUserRepo() *mockUserRepo {
	return &mockUserRepo{users: make(map[string]*domain.User)}
}

func (m *mockUserRepo) Create(ctx context.Context, user *domain.User) error {
	m.users[user.Email] = user
	return nil
}

func (m *mockUserRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	if u, ok := m.users[email]; ok {
		return u, nil
	}
	return nil, context.DeadlineExceeded // simulate not found
}

func (m *mockUserRepo) GetByID(ctx context.Context, id string) (*domain.User, error) {
	for _, u := range m.users {
		if u.ID == id {
			return u, nil
		}
	}
	return nil, context.DeadlineExceeded
}

func (m *mockUserRepo) Update(ctx context.Context, user *domain.User) error {
	for _, u := range m.users {
		if u.ID == user.ID {
			u.FullName = user.FullName
			u.Bio = user.Bio
			u.Skills = user.Skills
			return nil
		}
	}
	return context.DeadlineExceeded
}

func (m *mockUserRepo) SetCoverageBoost(ctx context.Context, userID string, durationDays int) error {
	return nil
}

func (m *mockUserRepo) SetRoamBoost(ctx context.Context, userID string, durationDays int) error {
	return nil
}

func (m *mockUserRepo) ToggleCoverageBoost(ctx context.Context, userID string, active bool) error {
	return nil
}
