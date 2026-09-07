package postgres

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5"
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
	query := "SELECT id, customer_id, title, description, category, status, max_budget, payment_method, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at FROM jobs WHERE status IN ('PUBLISHED', 'BIDDING')"
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
		err := rows.Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.PaymentMethod, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt)
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
	query := "SELECT id, customer_id, title, description, category, status, max_budget, payment_method, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at FROM jobs WHERE id = $1"
	var j domain.Job
	err := r.db.QueryRow(ctx, query, id).Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.PaymentMethod, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &j, nil
}

func (r *marketplaceRepo) CreateJob(ctx context.Context, job *domain.Job) error {
	_, err := r.db.Exec(ctx,
		"INSERT INTO jobs (id, customer_id, title, description, category, status, max_budget, payment_method, is_emergency, location, recurrence_type, total_occurrences, parent_job_id, scheduled_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, ST_SetSRID(ST_MakePoint($10, $11), 4326)::geography, $12, $13, $14, $15)",
		job.ID, job.CustomerID, job.Title, job.Description, job.Category, job.Status, job.MaxBudget, job.PaymentMethod, job.IsEmergency, job.Lng, job.Lat, job.RecurrenceType, job.TotalOccurrences, job.ParentJobID, job.ScheduledAt)
	if err != nil {
		log.Printf("[DB ERROR] CreateJob: %v", err)
		return fmt.Errorf("failed to create job: %w", err)
	}
	return nil
}

func (r *marketplaceRepo) CreateBid(ctx context.Context, bid *domain.Bid) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	owner, status, err := r.lockJob(ctx, tx, bid.JobID)
	if err != nil {
		return err
	}
	if owner == bid.ProviderID || (status != "PUBLISHED" && status != "BIDDING") {
		return fmt.Errorf("%w: job is not accepting this bid", domain.ErrConflict)
	}
	_, err = tx.Exec(ctx, "INSERT INTO bids(id,job_id,provider_id,amount,estimated_time,message,status) VALUES($1,$2,$3,$4,$5,$6,$7)", bid.ID, bid.JobID, bid.ProviderID, bid.Amount, bid.EstimatedTime, bid.Message, bid.Status)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
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

// Lock the job before examining bids so accept/counter/complete/cancel serialize.
func (r *marketplaceRepo) lockJob(ctx context.Context, tx pgx.Tx, jobID string) (string, string, error) {
	var owner, status string
	err := tx.QueryRow(ctx, "SELECT customer_id, status FROM jobs WHERE id=$1 FOR UPDATE", jobID).Scan(&owner, &status)
	return owner, status, err
}

func (r *marketplaceRepo) AcceptBid(ctx context.Context, jobID, bidID, userID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	owner, status, err := r.lockJob(ctx, tx, jobID)
	if err != nil {
		return err
	}
	if owner != userID {
		return fmt.Errorf("%w: only the job owner may accept bids", domain.ErrForbidden)
	}
	if status != "PUBLISHED" && status != "BIDDING" {
		return fmt.Errorf("%w: job is no longer accepting bids", domain.ErrConflict)
	}
	tag, err := tx.Exec(ctx, `UPDATE bids SET amount=CASE WHEN status='COUNTERED' THEN counter_amount ELSE amount END, status='ACCEPTED'
  WHERE id=$1 AND job_id=$2 AND (status='PENDING' OR (status='COUNTERED' AND counter_by <> $3::uuid))`, bidID, jobID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return fmt.Errorf("%w: bid is not an eligible offer for this job", domain.ErrConflict)
	}
	if _, err = tx.Exec(ctx, "UPDATE bids SET status='REJECTED', decline_reason='Another provider was selected' WHERE job_id=$1 AND id<>$2", jobID, bidID); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, "UPDATE jobs SET status='ACCEPTED', updated_at=NOW() WHERE id=$1", jobID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *marketplaceRepo) RejectBid(ctx context.Context, jobID, bidID, userID string, reason string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	owner, status, err := r.lockJob(ctx, tx, jobID)
	if err != nil {
		return err
	}
	if owner != userID {
		return domain.ErrForbidden
	}
	if status != "PUBLISHED" && status != "BIDDING" {
		return domain.ErrConflict
	}
	tag, err := tx.Exec(ctx, "UPDATE bids SET status='REJECTED', decline_reason=$1 WHERE id=$2 AND job_id=$3 AND status IN ('PENDING','COUNTERED')", reason, bidID, jobID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return fmt.Errorf("%w: eligible bid not found", domain.ErrConflict)
	}
	return tx.Commit(ctx)
}

func (r *marketplaceRepo) CounterBid(ctx context.Context, bidID, userID string, amount float64, reason string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	var jobID, provider string
	if err = tx.QueryRow(ctx, "SELECT job_id,provider_id FROM bids WHERE id=$1", bidID).Scan(&jobID, &provider); err != nil {
		return err
	}
	owner, status, err := r.lockJob(ctx, tx, jobID)
	if err != nil {
		return err
	}
	if owner != userID && provider != userID {
		return domain.ErrForbidden
	}
	if status != "PUBLISHED" && status != "BIDDING" {
		return domain.ErrConflict
	}
	tag, err := tx.Exec(ctx, `UPDATE bids SET amount=CASE WHEN status='COUNTERED' THEN counter_amount ELSE amount END,
 status='COUNTERED',counter_amount=$1,counter_by=$2,message=CASE WHEN $3<>'' THEN $3 ELSE message END
 WHERE id=$4 AND status IN ('PENDING','COUNTERED')`, amount, userID, reason, bidID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return fmt.Errorf("%w: eligible bid not found", domain.ErrConflict)
	}
	return tx.Commit(ctx)
}

func (r *marketplaceRepo) CompleteJob(ctx context.Context, jobID, userID string, score int, comment string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	owner, status, err := r.lockJob(ctx, tx, jobID)
	if err != nil {
		return err
	}
	if owner != userID {
		return fmt.Errorf("%w: only the customer may complete a job", domain.ErrForbidden)
	}
	if status == "COMPLETED" {
		return nil
	} // Retrying completion must not insert another rating.
	if status != "IN_PROGRESS" {
		return fmt.Errorf("%w: job must be in progress before completion", domain.ErrConflict)
	}
	var provider string
	if err = tx.QueryRow(ctx, "SELECT provider_id FROM bids WHERE job_id=$1 AND status='ACCEPTED'", jobID).Scan(&provider); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, "INSERT INTO ratings(job_id,provider_id,customer_id,score,comment) VALUES($1,$2,$3,$4,$5)", jobID, provider, userID, score, comment); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, "UPDATE jobs SET status='COMPLETED',updated_at=NOW() WHERE id=$1", jobID); err != nil {
		return err
	}
	return tx.Commit(ctx)
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
		SELECT id, customer_id, title, description, category, status, max_budget, payment_method, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at
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
		err := rows.Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.PaymentMethod, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt)
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

func (r *marketplaceRepo) GetJobsForCustomer(ctx context.Context, customerID string) ([]domain.Job, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, customer_id, title, description, category, status, max_budget, payment_method, is_emergency, ST_Y(location::geometry), ST_X(location::geometry), recurrence_type, total_occurrences, parent_job_id, scheduled_at, created_at
		FROM jobs
		WHERE customer_id = $1
		ORDER BY created_at DESC
	`, customerID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch customer jobs: %w", err)
	}
	defer rows.Close()

	jobs := []domain.Job{}
	for rows.Next() {
		var j domain.Job
		if err := rows.Scan(&j.ID, &j.CustomerID, &j.Title, &j.Description, &j.Category, &j.Status, &j.MaxBudget, &j.PaymentMethod, &j.IsEmergency, &j.Lat, &j.Lng, &j.RecurrenceType, &j.TotalOccurrences, &j.ParentJobID, &j.ScheduledAt, &j.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan customer job: %w", err)
		}
		jobs = append(jobs, j)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read customer jobs: %w", err)
	}
	return jobs, nil
}

func (r *marketplaceRepo) GetCategoryInsights(ctx context.Context, category string) (float64, int, error) {
	var avg float64
	var count int
	err := r.db.QueryRow(ctx, "SELECT COALESCE(AVG(amount),0), COUNT(*) FROM bids b JOIN jobs j ON b.job_id = j.id WHERE j.category = $1 AND b.status = 'ACCEPTED'", category).Scan(&avg, &count)
	return avg, count, err
}

func (r *marketplaceRepo) UpdateJobStatus(ctx context.Context, jobID, userID string, status string) error {
	previous := map[string]string{"EN_ROUTE": "ACCEPTED", "IN_PROGRESS": "EN_ROUTE"}[status]
	if previous == "" {
		return fmt.Errorf("%w: unsupported job transition", domain.ErrConflict)
	}
	tag, err := r.db.Exec(ctx, `UPDATE jobs SET status=$1,updated_at=NOW() WHERE id=$2 AND status=$3
 AND EXISTS(SELECT 1 FROM bids WHERE job_id=$2 AND provider_id=$4 AND status='ACCEPTED')`, status, jobID, previous, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return domain.ErrForbidden
	}
	return nil
}

func (r *marketplaceRepo) CancelJob(ctx context.Context, jobID, userID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	owner, status, err := r.lockJob(ctx, tx, jobID)
	if err != nil {
		return err
	}
	var participant bool
	if err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM bids WHERE job_id=$1 AND provider_id=$2 AND status='ACCEPTED')", jobID, userID).Scan(&participant); err != nil {
		return err
	}
	if owner != userID && !participant {
		return fmt.Errorf("%w: not permitted to cancel this job", domain.ErrForbidden)
	}
	if status == "CANCELLED" {
		return nil
	}
	if status == "COMPLETED" || status == "DISPUTED" {
		return fmt.Errorf("%w: job cannot be cancelled in its current state", domain.ErrConflict)
	}
	if _, err = tx.Exec(ctx, "UPDATE jobs SET status='CANCELLED',updated_at=NOW() WHERE id=$1", jobID); err != nil {
		return err
	}
	// The payment reconciler retries refunds by querying cancelled jobs, even after restarts.
	if _, err = tx.Exec(ctx, "INSERT INTO messages(job_id,sender_id,content) VALUES($1,NULL,'JOB_CANCELLED')", jobID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
