package service

import (
	"context"

	"github.com/service-marketplace/communication-service/internal/domain"
)

type mockChatRepo struct {
	messages []domain.Message
}

func newMockChatRepo() *mockChatRepo {
	return &mockChatRepo{messages: []domain.Message{}}
}

func (m *mockChatRepo) SaveMessage(ctx context.Context, msg *domain.Message) error {
	m.messages = append(m.messages, *msg)
	return nil
}

func (m *mockChatRepo) GetMessagesByJob(ctx context.Context, jobID string) ([]domain.Message, error) {
	res := []domain.Message{}
	for _, msg := range m.messages {
		if msg.JobID == jobID {
			res = append(res, msg)
		}
	}
	return res, nil
}
