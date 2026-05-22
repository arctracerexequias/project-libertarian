package domain

import (
	"context"
)

type User struct {
	ID           string   `json:"id"`
	Email        string   `json:"email"`
	PasswordHash string   `json:"-"`
	FullName     string   `json:"full_name"`
	Role         string   `json:"role"`
	IsVerified   bool     `json:"is_verified"`
	Bio          string   `json:"bio"`
	Skills       []string `json:"skills"`
}

type RegisterRequest struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
	FullName string `json:"full_name" binding:"required"`
	Role     string `json:"role" binding:"required"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type UserRepository interface {
	Create(ctx context.Context, user *User) error
	GetByEmail(ctx context.Context, email string) (*User, error)
	GetByID(ctx context.Context, id string) (*User, error)
	Update(ctx context.Context, user *User) error
}

type AuthService interface {
	Register(ctx context.Context, req RegisterRequest) (string, error)
	Login(ctx context.Context, req LoginRequest) (string, *User, error)
	GetProfile(ctx context.Context, userID string) (*User, error)
	UpdateProfile(ctx context.Context, userID string, fullName string, bio string, skills []string) error
	VerifyUser(ctx context.Context, userID string, isVerified bool) error
}
