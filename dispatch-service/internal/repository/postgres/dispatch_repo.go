package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/service-marketplace/dispatch-service/internal/domain"
)

type dispatchRepo struct {
	db *pgxpool.Pool
}

func NewDispatchRepository(db *pgxpool.Pool) domain.DispatchRepository {
	return &dispatchRepo{db: db}
}

func (r *dispatchRepo) UpdateLocation(ctx context.Context, loc *domain.ProviderLocation) error {
	_, err := r.db.Exec(ctx,
		"UPDATE providers SET location = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography WHERE user_id = $3",
		loc.Lng, loc.Lat, loc.ProviderID)
	if err != nil {
		return fmt.Errorf("failed to update provider location: %w", err)
	}
	return nil
}

func (r *dispatchRepo) FindNearbyProviders(ctx context.Context, lat, lng float64, category string, radius float64) ([]domain.ProviderLocation, error) {
	query := `
		SELECT user_id, ST_Y(location::geometry), ST_X(location::geometry)
		FROM providers 
		WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
		AND $4 = ANY(skills)
		ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)
		LIMIT 10
	`
	rows, err := r.db.Query(ctx, query, lng, lat, radius, category)
	if err != nil {
		return nil, fmt.Errorf("failed to search providers: %w", err)
	}
	defer rows.Close()

	var locations []domain.ProviderLocation
	for rows.Next() {
		var loc domain.ProviderLocation
		if err := rows.Scan(&loc.ProviderID, &loc.Lat, &loc.Lng); err != nil {
			continue
		}
		locations = append(locations, loc)
	}
	return locations, nil
}
