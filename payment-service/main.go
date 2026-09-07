package main

import (
	"context"
	"github.com/service-marketplace/payment-service/internal/provider"
	"log"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/payment-service/internal/handler/http"
	"github.com/service-marketplace/payment-service/internal/repository/postgres"
	"github.com/service-marketplace/payment-service/internal/service"
	"github.com/service-marketplace/shared-contracts/pkg/database"
	"github.com/service-marketplace/shared-contracts/pkg/middleware"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://user:password@localhost:5432/marketplace"
	}

	// Initialize Database
	dbPool, err := database.ConnectPostgres(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()

	// Initialize Layers
	repo := postgres.NewPaymentRepository(dbPool)
	svc := service.NewPaymentService(repo, provider.NewStripe(os.Getenv("STRIPE_SECRET_KEY"), os.Getenv("CHECKOUT_RETURN_URL")))
	handler := http.NewPaymentHandler(svc)

	r := gin.Default()
	r.Use(middleware.RequireGateway())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "payment-service"})
	})

	r.GET("/checkout/return", func(c *gin.Context) {
		c.String(200, "Return to the app and refresh payment status. Payment status is confirmed by the provider, not this page.")
	})
	go func() {
		for {
			ctx, cancel := context.WithTimeout(context.Background(), 50*time.Second)
			if err := svc.Reconcile(ctx); err != nil {
				log.Printf("Payment reconciliation: %v", err)
			}
			cancel()
			time.Sleep(30 * time.Second)
		}
	}()
	escrow := r.Group("/escrow", middleware.RequireAuth())
	{
		escrow.GET("/:jobId", handler.GetEscrow)
		escrow.POST("/init", handler.InitEscrow)
		escrow.POST("/release", handler.ReleaseEscrow)
		escrow.POST("/refund", handler.RefundEscrow)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8084"
	}

	log.Printf("Payment service starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}
