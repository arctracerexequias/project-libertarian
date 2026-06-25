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

func adminAuthMiddleware() gin.HandlerFunc {
	adminPassword := os.Getenv("ADMIN_PASSWORD")
	if adminPassword == "" {
		adminPassword = "admin_dev_password"
	}

	accounts := gin.Accounts{
		"admin": adminPassword,
	}
	return gin.BasicAuth(accounts)
}

func main() {
	initDB()
	defer dbPool.Close()

	r := gin.Default()

	// Public health check — no auth required
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "up", "service": "admin-service"})
	})

	// Protected routes — require Basic Auth
	protected := r.Group("/", adminAuthMiddleware())
	{
		protected.StaticFS("/dashboard", http.Dir("static"))

		protected.GET("/api/stats", func(c *gin.Context) {
			var totalUsers, totalProviders, verifiedProviders, unverifiedProviders, activeJobs int
			var totalRevenue float64

			type dbQuery struct {
				query string
				dest  interface{}
			}
			queries := []dbQuery{
				{"SELECT COUNT(*) FROM users", &totalUsers},
				{"SELECT COUNT(*) FROM users WHERE role = 'provider'", &totalProviders},
				{"SELECT COUNT(*) FROM users WHERE role = 'provider' AND is_verified = true", &verifiedProviders},
				{"SELECT COUNT(*) FROM users WHERE role = 'provider' AND is_verified = false", &unverifiedProviders},
				{"SELECT COUNT(*) FROM jobs WHERE status IN ('PUBLISHED', 'BIDDING', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS')", &activeJobs},
				{"SELECT COALESCE(SUM(amount), 0) FROM bids WHERE status = 'ACCEPTED'", &totalRevenue},
			}

			for _, q := range queries {
				if err := dbPool.QueryRow(context.Background(), q.query).Scan(q.dest); err != nil {
					log.Printf("[admin-service] stats query failed: %v", err)
					c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Database unavailable"})
					return
				}
			}

			c.JSON(http.StatusOK, gin.H{
				"total_users":          totalUsers,
				"total_providers":      totalProviders,
				"verified_providers":   verifiedProviders,
				"unverified_providers": unverifiedProviders,
				"active_jobs":          activeJobs,
				"total_revenue":        totalRevenue,
			})
		})
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8085"
	}
	log.Printf("Admin service starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}

