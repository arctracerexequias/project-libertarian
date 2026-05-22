package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

var dbPool *pgxpool.Pool

func initDB() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://user:password@localhost:5432/marketplace"
	}

	var err error
	dbPool, err = pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v\n", err)
	}
}

func main() {
	initDB()
	defer dbPool.Close()

	r := gin.Default()

	r.StaticFS("/dashboard", http.Dir("static"))

	r.GET("/api/stats", func(c *gin.Context) {
		var totalUsers, totalProviders, verifiedProviders, unverifiedProviders, activeJobs int
		var totalRevenue float64

		dbPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM users").Scan(&totalUsers)
		dbPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM users WHERE role = 'provider'").Scan(&totalProviders)
		dbPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM users WHERE role = 'provider' AND is_verified = true").Scan(&verifiedProviders)
		dbPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM users WHERE role = 'provider' AND is_verified = false").Scan(&unverifiedProviders)
		dbPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM jobs WHERE status IN ('PUBLISHED', 'BIDDING', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS')").Scan(&activeJobs)
		dbPool.QueryRow(context.Background(), "SELECT COALESCE(SUM(amount), 0) FROM bids WHERE status = 'ACCEPTED'").Scan(&totalRevenue)

		c.JSON(http.StatusOK, gin.H{
			"total_users":          totalUsers,
			"total_providers":      totalProviders,
			"verified_providers":   verifiedProviders,
			"unverified_providers": unverifiedProviders,
			"active_jobs":          activeJobs,
			"total_revenue":        totalRevenue,
		})
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "up", "service": "admin-service"})
	})

	r.Run("0.0.0.0:8085")
}
