package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

func initDB() *pgxpool.Pool {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://user:password@localhost:5432/marketplace"
	}

	dbPool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v\n", err)
	}
	return dbPool
}

func adminAuthMiddleware() gin.HandlerFunc {
	adminPassword := os.Getenv("ADMIN_PASSWORD")
	if adminPassword == "" {
		panic("ADMIN_PASSWORD is required")
	}

	accounts := gin.Accounts{
		"admin": adminPassword,
	}
	return gin.BasicAuth(accounts)
}

func main() {
	dbPool := initDB()
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

		protected.GET("/api/verification-requests", func(c *gin.Context) {
			rows, err := dbPool.Query(c.Request.Context(), `SELECT v.provider_id,u.full_name,v.status,v.requested_at::text
         FROM verification_requests v JOIN users u ON u.id=v.provider_id ORDER BY requested_at`)
			if err != nil {
				c.JSON(503, gin.H{"error": "Database unavailable"})
				return
			}
			defer rows.Close()
			requests := []gin.H{}
			for rows.Next() {
				var id, name, status, requested string
				if err := rows.Scan(&id, &name, &status, &requested); err != nil {
					c.JSON(503, gin.H{"error": "Database unavailable"})
					return
				}
				requests = append(requests, gin.H{"provider_id": id, "full_name": name, "status": status, "requested_at": requested})
			}
			if rows.Err() != nil {
				c.JSON(503, gin.H{"error": "Database unavailable"})
				return
			}
			c.JSON(200, requests)
		})
		protected.POST("/api/providers/:id/verification", func(c *gin.Context) {
			if c.ContentType() != "application/json" {
				c.JSON(415, gin.H{"error": "application/json required"})
				return
			}
			var req struct {
				Approve *bool  `json:"approve" binding:"required"`
				Note    string `json:"note" binding:"required,min=10"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(400, gin.H{"error": "approve and a review note of at least 10 characters are required"})
				return
			}
			ctx := c.Request.Context()
			tx, err := dbPool.Begin(ctx)
			if err != nil {
				c.JSON(503, gin.H{"error": "Database unavailable"})
				return
			}
			defer tx.Rollback(ctx)
			status := "REJECTED"
			if *req.Approve {
				status = "APPROVED"
			}
			reviewer, _, _ := c.Request.BasicAuth()
			tag, err := tx.Exec(ctx, "UPDATE verification_requests SET status=$1,reviewed_at=NOW(),review_note=$2,reviewed_by=$3 WHERE provider_id=$4 AND status='PENDING'", status, req.Note, reviewer, c.Param("id"))
			if err != nil {
				c.JSON(400, gin.H{"error": "Invalid verification request"})
				return
			}
			if tag.RowsAffected() != 1 {
				c.JSON(409, gin.H{"error": "No pending verification request"})
				return
			}
			if _, err = tx.Exec(ctx, "UPDATE users SET is_verified=$1 WHERE id=$2 AND role='provider'", *req.Approve, c.Param("id")); err != nil {
				c.JSON(503, gin.H{"error": "Database unavailable"})
				return
			}
			if _, err = tx.Exec(ctx, "UPDATE providers SET is_verified=$1 WHERE user_id=$2", *req.Approve, c.Param("id")); err != nil {
				c.JSON(503, gin.H{"error": "Database unavailable"})
				return
			}
			if err = tx.Commit(ctx); err != nil {
				c.JSON(503, gin.H{"error": "Database unavailable"})
				return
			}
			c.JSON(200, gin.H{"status": status})
		})
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
