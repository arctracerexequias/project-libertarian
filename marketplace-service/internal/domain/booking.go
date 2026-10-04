package domain

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"strings"
	"time"
)

// Booking keeps client contact and sensitive intake separate from public notes.
// Photos are bounded, atomically persisted with the request, and participant-only.
type Booking struct {
	Area      string            `json:"area"`
	Workers   int               `json:"workers"`
	UnitOffer float64           `json:"unit_offer"`
	EndAt     *time.Time        `json:"end_at,omitempty"`
	EndASAP   bool              `json:"end_asap"`
	Answers   map[string]string `json:"answers,omitempty"`
	Private   *PrivateBooking   `json:"private,omitempty"`
}
type PrivateBooking struct {
	Address string            `json:"address"`
	Contact string            `json:"contact"`
	Answers map[string]string `json:"answers,omitempty"`
	Photos  []BookingPhoto    `json:"photos,omitempty"`
}
type BookingPhoto struct {
	Name string `json:"name"`
	Data string `json:"data"` // Base64 JPEG or PNG; no executable or remote content.
}

func (b *Booking) Validate(start *time.Time, total float64) error {
	if b == nil {
		return nil
	} // Existing API clients remain compatible.
	if strings.TrimSpace(b.Area) == "" || len(b.Area) > 200 || b.Private == nil || strings.TrimSpace(b.Private.Address) == "" || len(b.Private.Address) > 500 || len(b.Private.Contact) < 7 || len(b.Private.Contact) > 40 {
		return fmt.Errorf("complete the booking address and contact information")
	}
	if b.Workers < 1 || b.Workers > 120 || b.UnitOffer <= 0 || math.IsNaN(b.UnitOffer) || math.IsInf(b.UnitOffer, 0) || math.Abs(total-b.UnitOffer*float64(b.Workers)) > 0.005 || math.Abs(b.UnitOffer*100-math.Round(b.UnitOffer*100)) > 0.00001 {
		return fmt.Errorf("invalid worker count or total offer")
	}
	if !b.EndASAP && (b.EndAt == nil || (start != nil && !b.EndAt.After(*start))) {
		return fmt.Errorf("service end must be after the start")
	}
	if b.EndASAP {
		b.EndAt = nil
	}
	for _, answers := range []map[string]string{b.Answers, b.Private.Answers} {
		if len(answers) > 40 {
			return fmt.Errorf("too many service answers")
		}
		for key, value := range answers {
			if len(key) > 160 || len(value) > 2000 {
				return fmt.Errorf("service answer is too long")
			}
		}
	}
	if len(b.Private.Photos) > 5 {
		return fmt.Errorf("attach up to five photos")
	}
	for _, photo := range b.Private.Photos {
		if len(photo.Name) > 200 || len(photo.Data) > 2800000 {
			return fmt.Errorf("photos must be JPEG or PNG, at most 2 MB each")
		}
		data, err := base64.StdEncoding.DecodeString(photo.Data)
		if err != nil || len(data) > 2*1024*1024 {
			return fmt.Errorf("invalid photo data")
		}
		config, format, err := image.DecodeConfig(bytes.NewReader(data))
		if err != nil || (format != "jpeg" && format != "png") || config.Width < 1 || config.Height < 1 || int64(config.Width)*int64(config.Height) > 24000000 {
			return fmt.Errorf("use a JPEG or PNG photo up to 24 megapixels")
		}
	}
	return nil
}

// ForViewer returns a copy: redaction must not mutate repository-cached data.
func (j Job) ForViewer(viewer string) Job {
	if viewer != "" && (viewer == j.CustomerID || viewer == j.AcceptedProviderID) {
		return j
	}
	if j.Booking != nil {
		copy := *j.Booking
		copy.Private = nil
		j.Booking = &copy
	}
	// Earlier clients appended contact lines to public descriptions.
	lines := strings.Split(j.Description, "\n")
	for i, line := range lines {
		trimmed := strings.ToLower(strings.TrimSpace(line))
		if strings.HasPrefix(trimmed, "address:") || strings.HasPrefix(trimmed, "contact:") || strings.HasPrefix(trimmed, "attached photos:") {
			lines[i] = "[Private information available after acceptance]"
		}
	}
	j.Description = strings.Join(lines, "\n")
	// Approximate coordinates suffice for browsing; precise location is private.
	j.Lat = math.Round(j.Lat*100) / 100
	j.Lng = math.Round(j.Lng*100) / 100
	return j
}
