package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/marketplace-service/internal/handler/http"
	"github.com/service-marketplace/marketplace-service/internal/repository/postgres"
	"github.com/service-marketplace/marketplace-service/internal/service"
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

	// Initialize Layers (Dependency Injection)
	repo := postgres.NewMarketplaceRepository(dbPool)
	svc := service.NewMarketplaceService(repo)
	handler := http.NewMarketplaceHandler(svc)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "marketplace-service"})
	})

	jobRoutes := r.Group("/jobs")
	{
		jobRoutes.GET("/", handler.GetJobs)
		jobRoutes.POST("/", handler.PostJob)
		jobRoutes.POST("/:id/bids", handler.PlaceBid)
		jobRoutes.GET("/:id/bids", handler.GetBids)
		jobRoutes.POST("/:id/accept/:bidId", handler.AcceptBid)
		jobRoutes.POST("/:id/complete", handler.CompleteJob)
		jobRoutes.POST("/:id/status", handler.UpdateJobStatus)
		jobRoutes.GET("/provider/bids", handler.GetProviderBids)
		jobRoutes.GET("/provider/jobs", handler.GetProviderJobs)
		jobRoutes.GET("/insights", handler.GetInsights)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8082"
	}

	log.Printf("Marketplace service starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}
