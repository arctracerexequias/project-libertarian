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

		// Initialize Wallet
		_, err = tx.Exec(ctx, "INSERT INTO provider_wallets (provider_id, balance) VALUES ($1, 0.0) ON CONFLICT DO NOTHING", user.ID)
		if err != nil {
			return fmt.Errorf("failed to initialize wallet: %w", err)
		}

		// Save Establishment if provided
		if user.Establishment != nil {
			_, err = tx.Exec(ctx, `
				INSERT INTO establishments (provider_id, name, business_type, registration_number, address)
				VALUES ($1, $2, $3, $4, $5)
			`, user.ID, user.Establishment.Name, user.Establishment.BusinessType, user.Establishment.RegistrationNumber, user.Establishment.Address)
			if err != nil {
				return fmt.Errorf("failed to save establishment: %w", err)
			}
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

	if user.Role == "provider" {
		r.fetchProviderMetrics(ctx, &user)
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

	if user.Role == "provider" {
		r.fetchProviderMetrics(ctx, &user)
	}

	return &user, nil
}

func (r *userRepo) fetchProviderMetrics(ctx context.Context, user *domain.User) {
	// 1. Fetch Job Count (Sum of Occurrences) and Total Earnings
	// Every occurrence in a recurring job counts as 1 job served
	err := r.db.QueryRow(ctx, `
		SELECT 
			COALESCE(SUM(j.total_occurrences), 0),
			COALESCE(SUM(b.amount), 0.0)
		FROM jobs j
		JOIN bids b ON j.id = b.job_id
		WHERE b.provider_id = $1 AND b.status = 'ACCEPTED' AND j.status = 'COMPLETED'
	`, user.ID).Scan(&user.CompletedJobsCount, &user.TotalAccumulatedAmount)
	if err != nil {
		fmt.Printf("Warning: failed to fetch job metrics for provider %s: %v\n", user.ID, err)
	}

	// 2. Fetch Average Rating and Rebook Count
	err = r.db.QueryRow(ctx, `
		SELECT 
			COALESCE(AVG(score), 5.0),
			(SELECT COUNT(*) FROM jobs WHERE parent_job_id IS NOT NULL AND id IN (SELECT job_id FROM bids WHERE provider_id = $1 AND status = 'ACCEPTED'))
		FROM ratings 
		WHERE provider_id = $1
	`, user.ID).Scan(&user.AverageRating, &user.RebookCount)
	if err != nil {
		fmt.Printf("Warning: failed to fetch performance metrics for provider %s: %v\n", user.ID, err)
	}

	// 3. Fetch Establishment
	var est domain.Establishment
	err = r.db.QueryRow(ctx, `
		SELECT name, business_type, registration_number, address 
		FROM establishments 
		WHERE provider_id = $1 AND is_active = TRUE 
		LIMIT 1
	`, user.ID).Scan(&est.Name, &est.BusinessType, &est.RegistrationNumber, &est.Address)
	if err == nil {
		user.Establishment = &est
	}

	// 4. Fetch Wallet Balance
	r.db.QueryRow(ctx, "SELECT balance FROM provider_wallets WHERE provider_id = $1", user.ID).Scan(&user.WalletBalance)
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

		// Update or Insert Establishment
		if user.Establishment != nil {
			_, err = tx.Exec(ctx, `
				INSERT INTO establishments (provider_id, name, business_type, registration_number, address)
				VALUES ($1, $2, $3, $4, $5)
				ON CONFLICT (id) DO UPDATE SET name = $2, business_type = $3, registration_number = $4, address = $5
			`, user.ID, user.Establishment.Name, user.Establishment.BusinessType, user.Establishment.RegistrationNumber, user.Establishment.Address)
			if err != nil {
				return fmt.Errorf("failed to update establishment: %w", err)
			}
		}

		// Update Wallet Balance (for top-ups)
		if user.WalletBalance > 0 {
			_, err = tx.Exec(ctx, "UPDATE provider_wallets SET balance = balance + $1 WHERE provider_id = $2", user.WalletBalance, user.ID)
			if err != nil {
				return fmt.Errorf("failed to update wallet balance: %w", err)
			}
		}
	}

	return tx.Commit(ctx)
}
