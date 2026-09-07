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

func authMiddleware(jwtKey []byte) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Public routes that don't need JWT auth
		c.Request.Header.Del("X-User-Id")
		c.Request.Header.Del("X-User-Role")
		c.Request.Header.Del("X-Gateway-Token")
		path := c.Request.URL.Path
		if (c.Request.Method == "POST" && (path == "/api/v1/identity/auth/login" || path == "/api/v1/identity/auth/register")) ||
			path == "/health" || (c.Request.Method == "GET" && path == "/api/v1/payment/checkout/return") ||
			strings.HasPrefix(path, "/api/v1/admin/") { // Admin has its own Basic Auth
			c.Next()
			return
		}

		authHeader := c.GetHeader("Authorization")
		var tokenString string
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString = strings.TrimPrefix(authHeader, "Bearer ")
		} else if path == "/api/v1/communication/chat/ws" {
			tokenString = c.Query("token")
		}

		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization token is required"})
			c.Abort()
			return
		}
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return jwtKey, nil
		}, jwt.WithValidMethods([]string{"HS256"}), jwt.WithExpirationRequired())

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			if userID, ok := claims["sub"].(string); ok && userID != "" {
				c.Request.Header.Set("X-User-Id", userID)
				role, _ := claims["role"].(string)
				c.Request.Header.Set("X-User-Role", role)
			} else {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token subject"})
				c.Abort()
				return
			}
		}

		c.Next()
	}
}

func proxy(target, gatewaySecret string) gin.HandlerFunc {
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
		} else if strings.HasPrefix(path, "/api/v1/admin/") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/admin")
		} else if strings.HasPrefix(path, "/api/v1/dispatch") {
			c.Request.URL.Path = strings.TrimPrefix(path, "/api/v1/dispatch")
		}

		query := c.Request.URL.Query()
		query.Del("token")
		c.Request.URL.RawQuery = query.Encode()
		c.Request.Header.Set("X-Gateway-Token", gatewaySecret)
		proxy.ServeHTTP(c.Writer, c.Request)
	}
}

func main() {
	jwtKey := []byte(os.Getenv("JWT_SECRET"))
	gatewaySecret := os.Getenv("GATEWAY_SECRET")
	if len(jwtKey) < 32 || len(gatewaySecret) < 32 {
		panic("JWT_SECRET and GATEWAY_SECRET must contain at least 32 characters")
	}
	r := gin.New()
	r.Use(gin.Recovery(), gin.LoggerWithFormatter(func(p gin.LogFormatterParams) string {
		return fmt.Sprintf("%s %s %d %s\n", p.Method, p.Request.URL.Path, p.StatusCode, p.Latency)
	}))
	r.Use(authMiddleware(jwtKey))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "up",
			"service": "api-gateway",
		})
	})

	// Basic Routing to Microservices (Internal Docker Networking)
	r.Any("/api/v1/identity/*any", proxy("http://identity-service:8081", gatewaySecret))
	r.Any("/api/v1/marketplace/*any", proxy("http://marketplace-service:8082", gatewaySecret))
	r.Any("/api/v1/communication/*any", proxy("http://communication-service:8083", gatewaySecret))
	r.Any("/api/v1/payment/*any", proxy("http://payment-service:8084", gatewaySecret))
	r.Any("/api/v1/admin/*any", proxy("http://admin-service:8085", gatewaySecret))
	r.Any("/api/v1/dispatch/*any", proxy("http://dispatch-service:8086", gatewaySecret))

	r.Run("0.0.0.0:8080")
}
