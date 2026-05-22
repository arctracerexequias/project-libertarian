package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/service-marketplace/communication-service/internal/domain"
)

type chatService struct {
	repo domain.ChatRepository
}

func NewChatService(repo domain.ChatRepository) domain.ChatService {
	return &chatService{repo: repo}
}

func (s *chatService) SendMessage(ctx context.Context, jobID, senderID, content string) (*domain.Message, error) {
	msg := &domain.Message{
		ID:        uuid.New().String(),
		JobID:     jobID,
		SenderID:  senderID,
		Content:   content,
		CreatedAt: time.Now(),
	}

	if err := s.repo.SaveMessage(ctx, msg); err != nil {
		return nil, err
	}

	return msg, nil
}

func (s *chatService) GetChatHistory(ctx context.Context, jobID string) ([]domain.Message, error) {
	return s.repo.GetMessagesByJob(ctx, jobID)
}
