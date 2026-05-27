package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/service-marketplace/identity-service/internal/domain"
)

type userRepo struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) domain.UserRepository {
	return &userRepo{db: db}
}

func (r *userRepo) Create(ctx context.Context, user *domain.User) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		"INSERT INTO users (id, email, password_hash, role, full_name) VALUES ($1, $2, $3, $4, $5)",
		user.ID, user.Email, user.PasswordHash, user.Role, user.FullName)
	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	if user.Role == "provider" {
		_, err = tx.Exec(ctx,
			"INSERT INTO providers (user_id, bio, skills, reputation_score, is_verified) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (user_id) DO NOTHING",
			user.ID, "", []string{}, 5.0, false)
		if err != nil {
			return fmt.Errorf("failed to create provider record: %w", err)
		}
	}

	return tx.Commit(ctx)
}

func (r *userRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	err := r.db.QueryRow(ctx,
		"SELECT id, email, password_hash, full_name, role, is_verified, COALESCE(bio,''), COALESCE(skills, ARRAY[]::TEXT[]) FROM users WHERE email = $1",
		email).Scan(&user.ID, &user.Email, &user.PasswordHash, &user.FullName, &user.Role, &user.IsVerified, &user.Bio, &user.Skills)
	if err != nil {
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}
	return &user, nil
}

func (r *userRepo) GetByID(ctx context.Context, id string) (*domain.User, error) {
	var user domain.User
	err := r.db.QueryRow(ctx,
		"SELECT id, email, full_name, role, is_verified, COALESCE(bio,''), COALESCE(skills, ARRAY[]::TEXT[]) FROM users WHERE id = $1",
		id).Scan(&user.ID, &user.Email, &user.FullName, &user.Role, &user.IsVerified, &user.Bio, &user.Skills)
	if err != nil {
		return nil, fmt.Errorf("failed to get user by id: %w", err)
	}
	return &user, nil
}

func (r *userRepo) Update(ctx context.Context, user *domain.User) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		"UPDATE users SET full_name = $1, bio = $2, skills = $3, is_verified = $4 WHERE id = $5",
		user.FullName, user.Bio, user.Skills, user.IsVerified, user.ID)
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	if user.Role == "provider" {
		_, err = tx.Exec(ctx,
			"INSERT INTO providers (user_id, bio, skills, reputation_score, is_verified) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (user_id) DO UPDATE SET bio = $2, skills = $3, is_verified = $5",
			user.ID, user.Bio, user.Skills, 5.0, user.IsVerified)
		if err != nil {
			return fmt.Errorf("failed to update provider record: %w", err)
		}
	}

	return tx.Commit(ctx)
}
