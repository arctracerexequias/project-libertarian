package main

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

var jwtKey = []byte(os.Getenv("JWT_SECRET"))

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Public routes that don't need auth
		path := c.Request.URL.Path
		if strings.Contains(path, "/auth/login") || strings.Contains(path, "/auth/register") || path == "/health" {
			c.Next()
			return
		}

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return jwtKey, nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			userID := claims["sub"].(string)
			c.Request.Header.Set("X-User-Id", userID)
		}

		c.Next()
	}
}

func proxy(target string) gin.HandlerFunc {
	url, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(url)

	return func(c *gin.Context) {
		c.Request.Host = url.Host
		c.Request.URL.Host = url.Host
		c.Request.URL.Scheme = url.Scheme

		path := c.Request.URL.Path
		if strings.HasPrefix(path, "/api/v1/identity") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/identity")
		} else if strings.HasPrefix(path, "/api/v1/marketplace") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/marketplace")
		} else if strings.HasPrefix(path, "/api/v1/communication") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/communication")
		} else if strings.HasPrefix(path, "/api/v1/payment") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/payment")
		} else if strings.HasPrefix(path, "/api/v1/admin") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/admin")
		} else if strings.HasPrefix(path, "/api/v1/dispatch") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/dispatch")
		}

		proxy.ServeHTTP(c.Writer, c.Request)
	}
}

func main() {
	r := gin.Default()
	r.Use(authMiddleware())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "up",
			"service": "api-gateway",
		})
	})

	// Basic Routing to Microservices (Internal Docker Networking)
	r.Any("/api/v1/identity/*any", proxy("http://identity-service:8081"))
	r.Any("/api/v1/marketplace/*any", proxy("http://marketplace-service:8082"))
	r.Any("/api/v1/communication/*any", proxy("http://communication-service:8083"))
	r.Any("/api/v1/payment/*any", proxy("http://payment-service:8084"))
	r.Any("/api/v1/admin/*any", proxy("http://admin-service:8085"))
	r.Any("/api/v1/dispatch/*any", proxy("http://dispatch-service:8086"))

	r.Run("0.0.0.0:8080")
}
