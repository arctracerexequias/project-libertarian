package postgres

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/service-marketplace/marketplace-service/internal/domain"
)

type marketplaceRepo struct {
	db *pgxpool.Pool
}

func NewMarketplaceRepository(db *pgxpool.Pool) domain.MarketplaceRepository {
	return &marketplaceRepo{db: db}
}

func (r *marketplaceRepo) GetJobs(ctx context.Context, category string, lat, lng, radius float64) ([]domain.Job, error) {
	query := "SELECT id, customer_id, title, description, category, status, max_budget, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at FROM jobs WHERE status IN ('PUBLISHED', 'BIDDING')"
	var args []interface{}
	argCount := 1

	if category != "" {
		query += fmt.Sprintf(" AND category = $%d", argCount)
		args = append(args, category)
		argCount++
	}

	if lat != 0 && lng != 0 && radius > 0 {
		query += fmt.Sprintf(" AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($%d, $%d), 4326)::geography, $%d)", argCount, argCount+1, argCount+2)
		args = append(args, lng, lat, radius)
		argCount += 3
	}

	query += " ORDER BY is_emergency DESC, created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch jobs: %w", err)
	}
	defer rows.Close()

	var jobs []domain.Job
	for rows.Next() {
		var j domain.Job
		err := rows.Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt)
		if err != nil {
			continue
		}
		jobs = append(jobs, j)
	}
	if jobs == nil {
		jobs = []domain.Job{}
	}
	return jobs, nil
}

func (r *marketplaceRepo) GetJobByID(ctx context.Context, id string) (*domain.Job, error) {
	query := "SELECT id, customer_id, title, description, category, status, max_budget, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at FROM jobs WHERE id = $1"
	var j domain.Job
	err := r.db.QueryRow(ctx, query, id).Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &j, nil
}

func (r *marketplaceRepo) CreateJob(ctx context.Context, job *domain.Job) error {
	_, err := r.db.Exec(ctx,
		"INSERT INTO jobs (id, customer_id, title, description, category, status, max_budget, is_emergency, location, recurrence_type, total_occurrences, parent_job_id, scheduled_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, ST_SetSRID(ST_MakePoint($9, $10), 4326)::geography, $11, $12, $13, $14)",
		job.ID, job.CustomerID, job.Title, job.Description, job.Category, job.Status, job.MaxBudget, job.IsEmergency, job.Lng, job.Lat, job.RecurrenceType, job.TotalOccurrences, job.ParentJobID, job.ScheduledAt)
	if err != nil {
		log.Printf("[DB ERROR] CreateJob: %v", err)
		return fmt.Errorf("failed to create job: %w", err)
	}
	return nil
}

func (r *marketplaceRepo) CreateBid(ctx context.Context, bid *domain.Bid) error {
	_, err := r.db.Exec(ctx,
		"INSERT INTO bids (id, job_id, provider_id, amount, estimated_time, message, status) VALUES ($1, $2, $3, $4, $5, $6, $7)",
		bid.ID, bid.JobID, bid.ProviderID, bid.Amount, bid.EstimatedTime, bid.Message, bid.Status)
	if err != nil {
		return fmt.Errorf("failed to submit bid: %w", err)
	}
	return nil
}

func (r *marketplaceRepo) GetBidsByJobID(ctx context.Context, jobID string) ([]domain.Bid, error) {
	rows, err := r.db.Query(ctx, `
		SELECT b.id, b.job_id, b.provider_id, b.amount, b.estimated_time, b.message, b.status, b.created_at,
		       COALESCE(b.decline_reason, '') as decline_reason,
		       COALESCE(b.counter_amount, 0.0) as counter_amount,
		       COALESCE(b.counter_by::text, '') as counter_by,
		       COALESCE(r.avg_score, 5.0) as provider_rating,
		       p.is_verified as provider_verified,
		       u.full_name as provider_name
		FROM bids b
		JOIN providers p ON b.provider_id = p.user_id
		JOIN users u ON p.user_id = u.id
		LEFT JOIN (
			SELECT provider_id, AVG(score) as avg_score
			FROM ratings
			GROUP BY provider_id
		) r ON b.provider_id = r.provider_id
		WHERE b.job_id = $1
	`, jobID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch bids: %w", err)
	}
	defer rows.Close()
	var bids []domain.Bid
	for rows.Next() {
		var b domain.Bid
		err := rows.Scan(&b.ID, &b.JobID, &b.ProviderID, &b.Amount, &b.EstimatedTime, &b.Message, &b.Status, &b.CreatedAt, &b.DeclineReason, &b.CounterAmount, &b.CounterBy, &b.ProviderRating, &b.ProviderVerified, &b.ProviderName)
		if err != nil {
			return nil, err
		}
		bids = append(bids, b)
	}
	if bids == nil {
		bids = []domain.Bid{}
	}
	return bids, nil
}

func (r *marketplaceRepo) AcceptBid(ctx context.Context, jobID, bidID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, "UPDATE bids SET amount = CASE WHEN status = 'COUNTERED' THEN counter_amount ELSE amount END, status = 'ACCEPTED' WHERE id = $1", bidID)
	if err != nil {
		return err
	}
	// Auto-reject other bids with a reason
	_, err = tx.Exec(ctx, "UPDATE bids SET status = 'REJECTED', decline_reason = 'Another provider was selected' WHERE job_id = $1 AND id != $2", jobID, bidID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, "UPDATE jobs SET status = 'ACCEPTED' WHERE id = $1", jobID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *marketplaceRepo) RejectBid(ctx context.Context, jobID, bidID string, reason string) error {
	_, err := r.db.Exec(ctx, "UPDATE bids SET status = 'REJECTED', decline_reason = $1 WHERE id = $2 AND job_id = $3", reason, bidID, jobID)
	return err
}

func (r *marketplaceRepo) CounterBid(ctx context.Context, bidID string, userID string, amount float64, reason string) error {
	_, err := r.db.Exec(ctx, "UPDATE bids SET amount = CASE WHEN status = 'COUNTERED' THEN counter_amount ELSE amount END, status = 'COUNTERED', counter_amount = $1, counter_by = $2, message = CASE WHEN $3 != '' THEN $3 ELSE message END WHERE id = $4", amount, userID, reason, bidID)
	return err
}

func (r *marketplaceRepo) CompleteJob(ctx context.Context, jobID, userID string, score int, comment string) error {
	var providerID string
	err := r.db.QueryRow(ctx, "UPDATE jobs SET status = 'COMPLETED' WHERE id = $1 RETURNING (SELECT provider_id FROM bids WHERE job_id = $1 AND status = 'ACCEPTED')", jobID).Scan(&providerID)
	if err != nil {
		return fmt.Errorf("failed to complete job: %w", err)
	}
	_, err = r.db.Exec(ctx, "INSERT INTO ratings (job_id, provider_id, customer_id, score, comment) VALUES ($1, $2, $3, $4, $5)", jobID, providerID, userID, score, comment)
	if err != nil {
		return fmt.Errorf("failed to insert rating: %w", err)
	}
	return nil
}

func (r *marketplaceRepo) GetBidsByProviderID(ctx context.Context, providerID string) ([]domain.Bid, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, job_id, provider_id, amount, estimated_time, message, status, created_at,
		       COALESCE(decline_reason, '') as decline_reason,
		       COALESCE(counter_amount, 0.0) as counter_amount,
		       COALESCE(counter_by::text, '') as counter_by
		FROM bids 
		WHERE provider_id = $1
	`, providerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var bids []domain.Bid
	for rows.Next() {
		var b domain.Bid
		err := rows.Scan(&b.ID, &b.JobID, &b.ProviderID, &b.Amount, &b.EstimatedTime, &b.Message, &b.Status, &b.CreatedAt, &b.DeclineReason, &b.CounterAmount, &b.CounterBy)
		if err != nil {
			return nil, err
		}
		bids = append(bids, b)
	}
	if bids == nil {
		bids = []domain.Bid{}
	}
	return bids, nil
}

func (r *marketplaceRepo) GetJobsForProvider(ctx context.Context, providerID string) ([]domain.Job, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, customer_id, title, description, category, status, max_budget, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at 
		FROM jobs 
		WHERE id IN (SELECT job_id FROM bids WHERE provider_id = $1 AND status = 'ACCEPTED')
	`, providerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var jobs []domain.Job
	for rows.Next() {
		var j domain.Job
		err := rows.Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt)
		if err != nil {
			continue
		}
		jobs = append(jobs, j)
	}
	if jobs == nil {
		jobs = []domain.Job{}
	}
	return jobs, nil
}

func (r *marketplaceRepo) GetCategoryInsights(ctx context.Context, category string) (float64, int, error) {
	var avg float64
	var count int
	err := r.db.QueryRow(ctx, "SELECT COALESCE(AVG(amount),0), COUNT(*) FROM bids b JOIN jobs j ON b.job_id = j.id WHERE j.category = $1 AND b.status = 'ACCEPTED'", category).Scan(&avg, &count)
	return avg, count, err
}

func (r *marketplaceRepo) UpdateJobStatus(ctx context.Context, jobID string, status string) error {
	_, err := r.db.Exec(ctx, "UPDATE jobs SET status = $1 WHERE id = $2", status, jobID)
	return err
}

func (r *marketplaceRepo) CancelJob(ctx context.Context, jobID string, userID string) error {
	// Only allow cancellation if user is the customer or the assigned provider
	// And if the job is not already completed
	query := `
		UPDATE jobs 
		SET status = 'CANCELLED' 
		WHERE id = $1 AND status NOT IN ('COMPLETED', 'CANCELLED')
		AND (customer_id = $2 OR id IN (SELECT job_id FROM bids WHERE provider_id = $2 AND status = 'ACCEPTED'))
	`
	tag, err := r.db.Exec(ctx, query, jobID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("job not found or unauthorized to cancel")
	}
	return nil
}
