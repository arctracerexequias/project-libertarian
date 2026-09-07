package provider

import (
	"context"
	"encoding/json"
	"github.com/service-marketplace/payment-service/internal/domain"
	"io"
	"net/http"
	"strings"
	"testing"
)

type transport func(*http.Request) (*http.Response, error)

func (f transport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func response(v interface{}) *http.Response {
	body, _ := json.Marshal(v)
	return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(string(body))), Header: make(http.Header)}
}
func TestCheckoutRequestUsesMinorUnitsAndManualCapture(t *testing.T) {
	s := NewStripe("test-key", "https://example.com/return")
	s.Client = &http.Client{Transport: transport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/v1/checkout/sessions" || r.Method != "POST" {
			t.Fatal("wrong endpoint")
		}
		if err := r.ParseForm(); err != nil {
			t.Fatal(err)
		}
		for key, want := range map[string]string{"line_items[0][price_data][currency]": "php", "line_items[0][price_data][unit_amount]": "125050", "payment_intent_data[capture_method]": "manual", "metadata[job_id]": "job"} {
			if r.Form.Get(key) != want {
				t.Errorf("%s=%q", key, r.Form.Get(key))
			}
		}
		if r.Header.Get("Idempotency-Key") != "tx-checkout" {
			t.Fatal("missing retry identity")
		}
		return response(map[string]string{"id": "cs_test", "url": "https://checkout.stripe.com/test"}), nil
	})}
	if _, err := s.CreateCheckout(context.Background(), &domain.Transaction{ID: "tx", JobID: "job", AmountMinor: 125050, Currency: "PHP"}); err != nil {
		t.Fatal(err)
	}
}
func TestCheckoutStatusComesFromIntent(t *testing.T) {
	for _, tt := range []struct{ stripeStatus, want string }{{"requires_payment_method", "PENDING"}, {"requires_capture", "HELD"}, {"succeeded", "RELEASED"}, {"canceled", "EXPIRED"}} {
		s := NewStripe("test-key", "")
		s.Client = &http.Client{Transport: transport(func(r *http.Request) (*http.Response, error) {
			if strings.Contains(r.URL.Path, "checkout/sessions") {
				return response(map[string]interface{}{"id": "cs_test", "status": "complete", "payment_intent": "pi_test", "amount_total": 10000, "currency": "php"}), nil
			}
			return response(map[string]interface{}{"id": "pi_test", "status": tt.stripeStatus, "amount": 10000, "currency": "php"}), nil
		})}
		got, err := s.Checkout(context.Background(), "cs_test")
		if err != nil {
			t.Fatal(err)
		}
		if got.Status != tt.want {
			t.Fatalf("%s yielded %s", tt.stripeStatus, got.Status)
		}
	}
}
