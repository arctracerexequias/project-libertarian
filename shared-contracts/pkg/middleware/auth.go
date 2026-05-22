package middleware

import (
	"github.com/gin-gonic/gin"
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
