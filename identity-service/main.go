package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/identity-service/internal/handler/http"
	"github.com/service-marketplace/identity-service/internal/repository/postgres"
	"github.com/service-marketplace/identity-service/internal/service"
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
	userRepo := postgres.NewUserRepository(dbPool)
	authService := service.NewAuthService(userRepo)
	authHandler := http.NewAuthHandler(authService)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "identity-service"})
	})

	auth := r.Group("/auth")
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
		auth.GET("/profile", authHandler.GetProfile)
		auth.PUT("/profile", authHandler.UpdateProfile)
		auth.POST("/verify-me", authHandler.VerifyMe)

		boost := auth.Group("/boost")
		{
			boost.POST("/coverage", authHandler.PurchaseCoverageBoost)
			boost.POST("/roam", authHandler.PurchaseRoamBoost)
			boost.POST("/coverage/toggle", authHandler.ToggleCoverageBoost)
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	log.Printf("Identity service starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}
