package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/service-marketplace/communication-service/internal/domain"
)

type chatRepo struct {
	db *pgxpool.Pool
}

func NewChatRepository(db *pgxpool.Pool) domain.ChatRepository {
	return &chatRepo{db: db}
}

func (r *chatRepo) SaveMessage(ctx context.Context, msg *domain.Message) error {
	_, err := r.db.Exec(ctx,
		"INSERT INTO messages (id, job_id, sender_id, content) VALUES ($1, $2, $3, $4)",
		msg.ID, msg.JobID, msg.SenderID, msg.Content)
	if err != nil {
		return fmt.Errorf("failed to save message: %w", err)
	}
	return nil
}

func (r *chatRepo) GetMessagesByJob(ctx context.Context, jobID string) ([]domain.Message, error) {
	rows, err := r.db.Query(ctx,
		"SELECT id, job_id, sender_id, content, created_at FROM messages WHERE job_id = $1 ORDER BY created_at ASC",
		jobID)
	if err != nil {
		return nil, fmt.Errorf("failed to get messages: %w", err)
	}
	defer rows.Close()

	var messages []domain.Message
	for rows.Next() {
		var m domain.Message
		err := rows.Scan(&m.ID, &m.JobID, &m.SenderID, &m.Content, &m.CreatedAt)
		if err != nil {
			continue
		}
		messages = append(messages, m)
	}
	if messages == nil {
		messages = []domain.Message{}
	}
	return messages, nil
}
