package middleware

import (
	"github.com/gin-gonic/gin"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestTrustedGatewayRequired(t *testing.T) {
	secret := strings.Repeat("x", 32)
	t.Setenv("GATEWAY_SECRET", secret)
	r := gin.New()
	r.Use(RequireGateway(), RequireAuth())
	r.GET("/private", func(c *gin.Context) { c.Status(204) })
	for _, tt := range []struct {
		secret, id string
		want       int
	}{{"", "forged", 401}, {"wrong", "forged", 401}, {secret, "", 401}, {secret, "user", 204}} {
		req := httptest.NewRequest("GET", "/private", nil)
		req.Header.Set("X-Gateway-Token", tt.secret)
		req.Header.Set("X-User-Id", tt.id)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != tt.want {
			t.Fatalf("got %d want %d", w.Code, tt.want)
		}
	}
}
