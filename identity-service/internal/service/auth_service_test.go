package service

import (
	"context"
	"os"
	"testing"

	"github.com/service-marketplace/identity-service/internal/domain"
)

func TestAuthService_Register(t *testing.T) {
	os.Setenv("JWT_SECRET", "test_secret")
	repo := newMockUserRepo()
	svc := NewAuthService(repo)

	req := domain.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
		FullName: "Test User",
		Role:     "customer",
	}

	userID, err := svc.Register(context.Background(), req)
	if err != nil {
		t.Fatalf("Failed to register user: %v", err)
	}

	if userID == "" {
		t.Fatal("Expected non-empty user ID")
	}

	// Verify user was stored in mock
	user, _ := repo.GetByEmail(context.Background(), req.Email)
	if user == nil {
		t.Fatal("User was not stored in repository")
	}
	if user.Email != req.Email {
		t.Errorf("Expected email %s, got %s", req.Email, user.Email)
	}
}

func TestAuthService_Login(t *testing.T) {
	os.Setenv("JWT_SECRET", "test_secret")
	repo := newMockUserRepo()
	svc := NewAuthService(repo)

	// Pre-register a user
	regReq := domain.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
		FullName: "Test User",
		Role:     "customer",
	}
	svc.Register(context.Background(), regReq)

	// Test successful login
	loginReq := domain.LoginRequest{
		Email:    "test@example.com",
		Password: "password123",
	}

	token, user, err := svc.Login(context.Background(), loginReq)
	if err != nil {
		t.Fatalf("Failed to login: %v", err)
	}

	if token == "" {
		t.Fatal("Expected non-empty token")
	}
	if user.Email != loginReq.Email {
		t.Errorf("Expected user email %s, got %s", loginReq.Email, user.Email)
	}

	// Test failed login (wrong password)
	wrongLoginReq := domain.LoginRequest{
		Email:    "test@example.com",
		Password: "wrongpassword",
	}

	_, _, err = svc.Login(context.Background(), wrongLoginReq)
	if err == nil {
		t.Fatal("Expected error for wrong password, got nil")
	}
}
