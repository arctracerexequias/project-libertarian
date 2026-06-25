package service

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/service-marketplace/identity-service/internal/domain"
	"golang.org/x/crypto/bcrypt"
)

type authService struct {
	repo   domain.UserRepository
	jwtKey []byte
}

func NewAuthService(repo domain.UserRepository) domain.AuthService {
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "super_secret_jwt_key_for_development"
	}
	return &authService{
		repo:   repo,
		jwtKey: []byte(jwtSecret),
	}
}

func (s *authService) Register(ctx context.Context, req domain.RegisterRequest) (string, error) {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("failed to hash password: %w", err)
	}

	userID := uuid.New().String()
	user := &domain.User{
		ID:           userID,
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		Role:         req.Role,
		FullName:     req.FullName,
	}

	if err := s.repo.Create(ctx, user); err != nil {
		return "", err
	}

	return userID, nil
}

func (s *authService) Login(ctx context.Context, req domain.LoginRequest) (string, *domain.User, error) {
	user, err := s.repo.GetByEmail(ctx, req.Email)
	if err != nil {
		return "", nil, fmt.Errorf("invalid credentials")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return "", nil, fmt.Errorf("invalid credentials")
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":  user.ID,
		"role": user.Role,
		"exp":  time.Now().Add(time.Hour * 24).Unix(),
	})

	tokenString, err := token.SignedString(s.jwtKey)
	if err != nil {
		return "", nil, fmt.Errorf("failed to sign token: %w", err)
	}

	return tokenString, user, nil
}

func (s *authService) GetProfile(ctx context.Context, userID string) (*domain.User, error) {
	return s.repo.GetByID(ctx, userID)
}

func (s *authService) UpdateProfile(ctx context.Context, userID string, fullName string, bio string, skills []string) error {
	user, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	user.FullName = fullName
	user.Bio = bio
	user.Skills = skills
	return s.repo.Update(ctx, user)
}

func (s *authService) VerifyUser(ctx context.Context, userID string, isVerified bool) error {
	user, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	user.IsVerified = isVerified
	return s.repo.Update(ctx, user)
}

func (s *authService) PurchaseCoverageBoost(ctx context.Context, userID string, durationDays int) error {
	return s.repo.SetCoverageBoost(ctx, userID, durationDays)
}

func (s *authService) PurchaseRoamBoost(ctx context.Context, userID string, durationDays int) error {
	return s.repo.SetRoamBoost(ctx, userID, durationDays)
}

func (s *authService) ToggleCoverageBoost(ctx context.Context, userID string, active bool) error {
	return s.repo.ToggleCoverageBoost(ctx, userID, active)
}
