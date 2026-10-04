package http

import (
	"context"
	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/marketplace-service/internal/domain"
	"net/http/httptest"
	"strings"
	"testing"
)

type bookingService struct {
	domain.MarketplaceService
	job domain.Job
}

func (s bookingService) GetJob(context.Context, string) (*domain.Job, error) {
	j := s.job
	return &j, nil
}
func (s bookingService) ListJobs(context.Context, string, float64, float64, float64) ([]domain.Job, error) {
	return []domain.Job{s.job}, nil
}
func TestBookingReadRoutesEnforceParticipantPrivacy(t *testing.T) {
	gin.SetMode(gin.TestMode)
	svc := bookingService{job: domain.Job{CustomerID: "owner", AcceptedProviderID: "selected", Booking: &domain.Booking{Area: "Makati", Private: &domain.PrivateBooking{Address: "secret-address", Contact: "secret-phone"}}}}
	handler := NewMarketplaceHandler(svc)
	r := gin.New()
	r.GET("/jobs/", handler.GetJobs)
	r.GET("/jobs/:id", handler.GetJobByID)
	for _, viewer := range []string{"owner", "selected", "bidder", ""} {
		for _, path := range []string{"/jobs/", "/jobs/id"} {
			request := httptest.NewRequest("GET", path, nil)
			request.Header.Set("X-User-Id", viewer)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, request)
			if w.Code != 200 {
				t.Fatal(w.Code)
			}
			wantPrivate := path == "/jobs/id" && (viewer == "owner" || viewer == "selected")
			if strings.Contains(w.Body.String(), "secret-address") != wantPrivate {
				t.Fatalf("incorrect privacy for %s %s: %s", viewer, path, w.Body.String())
			}
		}
	}
}
