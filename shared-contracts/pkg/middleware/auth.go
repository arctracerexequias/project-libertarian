package middleware

import (
	"crypto/subtle"
	"github.com/gin-gonic/gin"
	"os"
)

const HeaderXUserID = "X-User-Id"

// GetUserID extracts the user ID from the X-User-Id header.
func GetUserID(c *gin.Context) string {
	return c.GetHeader(HeaderXUserID)
}

// RequireAuth is a simple middleware that ensures the X-User-Id header is present.
func RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := GetUserID(c)
		if userID == "" {
			c.JSON(401, gin.H{"error": "Unauthorized: missing X-User-Id"})
			c.Abort()
			return
		}
		c.Next()
	}
}

// RequireGateway authenticates the internal hop; JWT validation remains at the gateway.
func RequireGateway() gin.HandlerFunc {
	secret := os.Getenv("GATEWAY_SECRET")
	if len(secret) < 32 {
		panic("GATEWAY_SECRET must contain at least 32 characters")
	}
	return func(c *gin.Context) {
		if c.Request.URL.Path == "/health" {
			c.Next()
			return
		}
		if subtle.ConstantTimeCompare([]byte(c.GetHeader("X-Gateway-Token")), []byte(secret)) != 1 {
			c.AbortWithStatusJSON(401, gin.H{"error": "Untrusted gateway"})
			return
		}
		c.Next()
	}
}
func RequireRole(role string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if GetUserID(c) == "" || c.GetHeader("X-User-Role") != role {
			c.AbortWithStatusJSON(403, gin.H{"error": "Role not permitted"})
			return
		}
		c.Next()
	}
}
