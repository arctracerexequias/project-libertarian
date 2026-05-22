package service

import (
	"context"

	"github.com/service-marketplace/payment-service/internal/domain"
)

type mockPaymentRepo struct {
	transactions map[string]*domain.Transaction
}

func newMockPaymentRepo() *mockPaymentRepo {
	return &mockPaymentRepo{transactions: make(map[string]*domain.Transaction)}
}

func (m *mockPaymentRepo) CreateTransaction(ctx context.Context, tx *domain.Transaction) error {
	m.transactions[tx.JobID] = tx
	return nil
}

func (m *mockPaymentRepo) GetTransactionByJobID(ctx context.Context, jobID string) (*domain.Transaction, error) {
	if tx, ok := m.transactions[jobID]; ok {
		return tx, nil
	}
	return nil, context.DeadlineExceeded
}

func (m *mockPaymentRepo) UpdateTransactionStatus(ctx context.Context, jobID, status string) error {
	if tx, ok := m.transactions[jobID]; ok {
		tx.Status = status
		return nil
	}
	return context.DeadlineExceeded
}
