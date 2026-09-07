package provider

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/service-marketplace/payment-service/internal/domain"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// Stripe uses hosted Checkout so card details never enter this backend or app.
// https://docs.stripe.com/payments/place-a-hold-on-a-payment-method
// https://docs.stripe.com/api/idempotent_requests
// The HTTP client and API base are injected for deterministic provider tests.
type Stripe struct {
	Key, ReturnURL, BaseURL string
	Client                  *http.Client
}

func NewStripe(key, returnURL string) *Stripe {
	return &Stripe{Key: key, ReturnURL: returnURL, BaseURL: "https://api.stripe.com/v1", Client: &http.Client{Timeout: 15 * time.Second}}
}
func (s *Stripe) request(ctx context.Context, method, path, key string, data url.Values, result interface{}) error {
	if s.Key == "" {
		return fmt.Errorf("online payments are not configured")
	}
	req, err := http.NewRequestWithContext(ctx, method, s.BaseURL+path, strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(s.Key, "")
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Stripe-Version", "2020-08-27")
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	resp, err := s.Client.Do(req)
	if err != nil {
		return fmt.Errorf("payment provider unavailable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("payment provider returned HTTP %d", resp.StatusCode)
	}
	if result == nil {
		return nil
	}
	return json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(result)
}
func (s *Stripe) CreateCheckout(ctx context.Context, t *domain.Transaction) (domain.Checkout, error) {
	u, err := url.Parse(s.ReturnURL)
	if err != nil || u.Host == "" || (u.Scheme != "https" && !(u.Scheme == "http" && (u.Hostname() == "localhost" || u.Hostname() == "127.0.0.1"))) {
		return domain.Checkout{}, fmt.Errorf("valid CHECKOUT_RETURN_URL required")
	}
	data := url.Values{"mode": {"payment"}, "payment_method_types[0]": {"card"}, "payment_intent_data[capture_method]": {"manual"},
		"success_url": {s.ReturnURL}, "cancel_url": {s.ReturnURL}, "client_reference_id": {t.JobID}, "metadata[job_id]": {t.JobID},
		"payment_intent_data[metadata][job_id]": {t.JobID}, "line_items[0][price_data][currency]": {strings.ToLower(t.Currency)},
		"line_items[0][price_data][unit_amount]": {strconv.FormatInt(t.AmountMinor, 10)}, "line_items[0][price_data][product_data][name]": {"Service booking"}, "line_items[0][quantity]": {"1"}}
	var response struct{ ID, URL string }
	err = s.request(ctx, "POST", "/checkout/sessions", t.ID+"-checkout", data, &response)
	if err == nil && (response.ID == "" || response.URL == "") {
		err = fmt.Errorf("invalid checkout response")
	}
	return domain.Checkout{ID: response.ID, URL: response.URL, Status: "PENDING", AmountMinor: t.AmountMinor, Currency: t.Currency}, err
}

type intent struct {
	ID, Status string
	Amount     int64
	Currency   string
}

func (s *Stripe) getIntent(ctx context.Context, id string) (intent, error) {
	var pi intent
	err := s.request(ctx, "GET", "/payment_intents/"+url.PathEscape(id), "", nil, &pi)
	return pi, err
}
func (s *Stripe) Checkout(ctx context.Context, id string) (domain.Checkout, error) {
	if strings.HasPrefix(id, "intent:") {
		pi, err := s.getIntent(ctx, strings.TrimPrefix(id, "intent:"))
		if err != nil {
			return domain.Checkout{}, err
		}
		status := "PENDING"
		switch pi.Status {
		case "requires_capture":
			status = "HELD"
		case "succeeded":
			status = "RELEASED"
		case "canceled":
			status = "EXPIRED"
		}
		return domain.Checkout{ID: id, IntentID: pi.ID, AmountMinor: pi.Amount, Currency: strings.ToUpper(pi.Currency), Status: status}, nil
	}

	var session struct {
		ID, URL, Status, Currency string
		AmountTotal               int64  `json:"amount_total"`
		PaymentIntent             string `json:"payment_intent"`
	}
	err := s.request(ctx, "GET", "/checkout/sessions/"+url.PathEscape(id), "", nil, &session)
	if err != nil {
		return domain.Checkout{}, err
	}
	c := domain.Checkout{ID: session.ID, URL: session.URL, IntentID: session.PaymentIntent, Status: "PENDING", AmountMinor: session.AmountTotal, Currency: strings.ToUpper(session.Currency)}
	if session.Status == "expired" {
		c.Status = "EXPIRED"
	}
	if c.IntentID != "" {
		pi, err := s.getIntent(ctx, c.IntentID)
		if err != nil {
			return c, err
		}
		if pi.Amount != c.AmountMinor || strings.ToUpper(pi.Currency) != c.Currency {
			return c, fmt.Errorf("checkout and intent amounts differ")
		}
		switch pi.Status {
		case "requires_capture":
			c.Status = "HELD"
		case "succeeded":
			c.Status = "RELEASED"
		case "canceled":
			c.Status = "EXPIRED"
		}
	}
	return c, nil
}
func (s *Stripe) Capture(ctx context.Context, id, key string) error {
	var pi intent
	if err := s.request(ctx, "POST", "/payment_intents/"+url.PathEscape(id)+"/capture", key, nil, &pi); err != nil {
		return err
	}
	if pi.Status != "succeeded" {
		return fmt.Errorf("capture has not succeeded")
	}
	return nil
}
func (s *Stripe) Refund(ctx context.Context, checkoutID, intentID, key string) error {
	if intentID == "" {
		c, err := s.Checkout(ctx, checkoutID)
		if err != nil {
			return err
		}
		if c.IntentID != "" {
			return s.Refund(ctx, checkoutID, c.IntentID, key)
		}
		if c.Status == "EXPIRED" {
			return nil
		}
		// Expiration can race checkout completion. On an error the worker fetches
		// fresh state next time and cancels/refunds the resulting intent instead.
		return s.request(ctx, "POST", "/checkout/sessions/"+url.PathEscape(checkoutID)+"/expire", key+"-expire", nil, nil)
	}
	pi, err := s.getIntent(ctx, intentID)
	if err != nil {
		return err
	}
	if pi.Status == "canceled" {
		return nil
	}
	if pi.Status == "succeeded" {
		var refund struct{ ID, Status string }
		if err = s.request(ctx, "POST", "/refunds", key, url.Values{"payment_intent": {intentID}}, &refund); err != nil {
			return err
		}
		if refund.Status != "succeeded" && refund.ID != "" {
			if err = s.request(ctx, "GET", "/refunds/"+url.PathEscape(refund.ID), "", nil, &refund); err != nil {
				return err
			}
		}
		if refund.Status != "succeeded" {
			return fmt.Errorf("refund is still pending")
		}
		return nil
	}
	return s.request(ctx, "POST", "/payment_intents/"+url.PathEscape(intentID)+"/cancel", key+"-cancel", nil, nil)
}
