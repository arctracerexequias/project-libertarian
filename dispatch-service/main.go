package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/dispatch-service/internal/handler/http"
	"github.com/service-marketplace/dispatch-service/internal/repository/postgres"
	"github.com/service-marketplace/dispatch-service/internal/service"
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
	repo := postgres.NewDispatchRepository(dbPool)
	svc := service.NewDispatchService(repo)
	handler := http.NewDispatchHandler(svc)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "dispatch-service"})
	})

	r.POST("/location", handler.UpdateLocation)
	r.POST("/dispatch", handler.Dispatch)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8086"
	}

	log.Printf("Dispatch service starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}
