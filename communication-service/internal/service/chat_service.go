package service

import (
	"context"
	"fmt"
	"strings"
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
	if err := s.Authorize(ctx, jobID, senderID); err != nil {
		return nil, err
	}
	if strings.TrimSpace(content) == "" || len(content) > 8000 {
		return nil, fmt.Errorf("message must contain 1 to 8000 bytes")
	}
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

func (s *chatService) GetChatHistory(ctx context.Context, jobID, userID string) ([]domain.Message, error) {
	if err := s.Authorize(ctx, jobID, userID); err != nil {
		return nil, err
	}
	return s.repo.GetMessagesByJob(ctx, jobID)
}

func (s *chatService) Authorize(ctx context.Context, jobID, userID string) error {
	if userID == "" {
		return fmt.Errorf("authentication required")
	}
	allowed, err := s.repo.IsParticipant(ctx, jobID, userID)
	if err != nil {
		return err
	}
	if !allowed {
		return fmt.Errorf("not a participant in this job")
	}
	return nil
}
