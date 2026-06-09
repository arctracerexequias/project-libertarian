package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/communication-service/internal/handler/http"
	"github.com/service-marketplace/communication-service/internal/repository/postgres"
	"github.com/service-marketplace/communication-service/internal/service"
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
	repo := postgres.NewChatRepository(dbPool)
	svc := service.NewChatService(repo)
	handler := http.NewChatHandler(svc)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "communication-service"})
	})

	chat := r.Group("/chat")
	{
		chat.GET("/history/:jobId", handler.GetHistory)
		chat.POST("/system", handler.SendSystemMessage)
		chat.GET("/ws", handler.HandleWebSocket)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8083"
	}

	log.Printf("Communication service starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}
