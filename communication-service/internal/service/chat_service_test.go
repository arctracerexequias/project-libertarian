package service

import (
	"context"
	"testing"
)

func TestChatService_SendMessage(t *testing.T) {
	repo := newMockChatRepo()
	svc := NewChatService(repo)

	jobID := "job-123"
	senderID := "user-456"
	content := "Hello, I'm interested in your job!"

	msg, err := svc.SendMessage(context.Background(), jobID, senderID, content)
	if err != nil {
		t.Fatalf("Failed to send message: %v", err)
	}

	if msg.ID == "" {
		t.Fatal("Expected non-empty message ID")
	}
	if msg.JobID != jobID {
		t.Errorf("Expected jobID %s, got %s", jobID, msg.JobID)
	}
	if msg.Content != content {
		t.Errorf("Expected content %s, got %s", content, msg.Content)
	}

	history, _ := repo.GetMessagesByJob(context.Background(), jobID)
	if len(history) != 1 {
		t.Fatalf("Expected 1 message in history, got %d", len(history))
	}
}

func TestChatService_GetChatHistory(t *testing.T) {
	repo := newMockChatRepo()
	svc := NewChatService(repo)

	jobID := "job-123"
	svc.SendMessage(context.Background(), jobID, "user-1", "Hi")
	svc.SendMessage(context.Background(), jobID, "user-2", "Hello")
	svc.SendMessage(context.Background(), "other-job", "user-1", "Wrong job")

	history, err := svc.GetChatHistory(context.Background(), jobID, "user-1")
	if err != nil {
		t.Fatalf("Failed to get chat history: %v", err)
	}

	if len(history) != 2 {
		t.Fatalf("Expected 2 messages for job-123, got %d", len(history))
	}
}

func TestChatRejectsOutsider(t *testing.T) {
	repo := newMockChatRepo()
	repo.denied = true
	svc := NewChatService(repo)
	if _, err := svc.SendMessage(context.Background(), "job", "outsider", "hello"); err == nil {
		t.Fatal("unauthorized send allowed")
	}
	if _, err := svc.GetChatHistory(context.Background(), "job", "outsider"); err == nil {
		t.Fatal("unauthorized read allowed")
	}
	if len(repo.messages) != 0 {
		t.Fatal("unauthorized message saved")
	}
}
