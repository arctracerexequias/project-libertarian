package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/payment-service/internal/handler/http"
	"github.com/service-marketplace/payment-service/internal/repository/postgres"
	"github.com/service-marketplace/payment-service/internal/service"
	"github.com/service-marketplace/shared-contracts/pkg/database"
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
	svc := service.NewPaymentService(repo)
	handler := http.NewPaymentHandler(svc)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "payment-service"})
	})

	escrow := r.Group("/escrow")
	{
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
