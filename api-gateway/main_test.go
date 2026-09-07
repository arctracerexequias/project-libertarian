package main

import (
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestGatewayDoesNotTrustCallerIdentity(t *testing.T) {
	jwtKey := []byte(strings.Repeat("k", 32))
	r := gin.New()
	r.Use(authMiddleware(jwtKey))
	r.Any("/*path", func(c *gin.Context) {
		c.JSON(200, gin.H{"id": c.GetHeader("X-User-Id"), "role": c.GetHeader("X-User-Role")})
	})
	token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"sub": "real-user", "role": "customer", "exp": time.Now().Add(time.Hour).Unix()}).SignedString(jwtKey)
	for _, tt := range []struct {
		path, token string
		want        int
	}{
		{"/api/v1/marketplace/jobs/", "", 401},
		{"/api/v1/marketplace/jobs/auth/login", "", 401},
		{"/api/v1/marketplace/jobs/", token, 200},
	} {
		req := httptest.NewRequest(http.MethodGet, tt.path, nil)
		req.Header.Set("X-User-Id", "forged")
		req.Header.Set("X-User-Role", "admin")
		if tt.token != "" {
			req.Header.Set("Authorization", "Bearer "+tt.token)
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != tt.want {
			t.Fatalf("%s: %d", tt.path, w.Code)
		}
		if w.Code == 200 && (strings.Contains(w.Body.String(), "forged") || strings.Contains(w.Body.String(), "admin")) {
			t.Fatal("forged identity forwarded")
		}
	}
}
func TestGatewayRequiresExpiryAndClearsPublicIdentity(t *testing.T) {
	jwtKey := []byte(strings.Repeat("k", 32))
	r := gin.New()
	r.Use(authMiddleware(jwtKey))
	r.Any("/*path", func(c *gin.Context) { c.String(200, c.GetHeader("X-User-Id")) })
	token, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"sub": "user"}).SignedString(jwtKey)
	req := httptest.NewRequest("GET", "/api/v1/marketplace/jobs/", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 401 {
		t.Fatal("unbounded token accepted")
	}
	req = httptest.NewRequest("POST", "/api/v1/identity/auth/login", nil)
	req.Header.Set("X-User-Id", "forged")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 200 || w.Body.String() != "" {
		t.Fatal("public route retained identity")
	}
}
