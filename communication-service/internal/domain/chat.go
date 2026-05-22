package domain

import (
	"context"
	"time"
)

type Message struct {
	ID        string    `json:"id"`
	JobID     string    `json:"job_id"`
	SenderID  string    `json:"sender_id"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type ChatRepository interface {
	SaveMessage(ctx context.Context, msg *Message) error
	GetMessagesByJob(ctx context.Context, jobID string) ([]Message, error)
}

type ChatService interface {
	SendMessage(ctx context.Context, jobID, senderID, content string) (*Message, error)
	GetChatHistory(ctx context.Context, jobID string) ([]Message, error)
}
