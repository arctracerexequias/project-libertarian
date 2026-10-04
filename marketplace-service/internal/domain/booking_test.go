package domain

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"strings"
	"testing"
	"time"
)

func TestBookingPrivacy(t *testing.T) {
	job := Job{CustomerID: "owner", AcceptedProviderID: "accepted", Lat: 14.55123, Lng: 121.01987,
		Description: "Fix the sink\nAddress: old secret address\nContact: 09171234567",
		Booking:     &Booking{Area: "Makati", Answers: map[string]string{"Task": "Cleaning"}, Private: &PrivateBooking{Address: "secret street", Contact: "09171234567", Answers: map[string]string{"Health": "private condition"}, Photos: []BookingPhoto{{Name: "private.jpg", Data: "private image"}}}}}
	for _, viewer := range []string{"", "bidder", "stranger"} {
		view := job.ForViewer(viewer)
		raw, _ := json.Marshal(view)
		for _, secret := range []string{"secret", "09171234567", "private condition", "private image", "14.55123"} {
			if strings.Contains(string(raw), secret) {
				t.Fatalf("%s leaked to %q", secret, viewer)
			}
		}
		if view.Booking.Answers["Task"] != "Cleaning" {
			t.Fatal("lost public service information")
		}
	}
	for _, viewer := range []string{"owner", "accepted"} {
		if job.ForViewer(viewer).Booking.Private == nil {
			t.Fatal("participant cannot see booking")
		}
	}
	if job.Booking.Private == nil {
		t.Fatal("redaction mutated stored job")
	}
}

func TestBookingValidation(t *testing.T) {
	start := time.Now().Add(time.Hour)
	end := start.Add(time.Hour)
	var img bytes.Buffer
	png.Encode(&img, image.NewRGBA(image.Rect(0, 0, 2, 2)))
	valid := func() *Booking {
		return &Booking{Area: "Makati", Workers: 2, UnitOffer: 600, EndAt: &end, Private: &PrivateBooking{Address: "Unit 3, Makati", Contact: "09171234567", Photos: []BookingPhoto{{Name: "photo.png", Data: base64.StdEncoding.EncodeToString(img.Bytes())}}}}
	}
	if err := valid().Validate(&start, 1200); err != nil {
		t.Fatal(err)
	}
	cases := map[string]func(*Booking){
		"wrong total":      func(b *Booking) { b.UnitOffer = 500 },
		"end before start": func(b *Booking) { b.EndAt = &start },
		"no contact":       func(b *Booking) { b.Private = nil },
		"not image":        func(b *Booking) { b.Private.Photos[0].Data = base64.StdEncoding.EncodeToString([]byte("not a photo")) },
		"oversized":        func(b *Booking) { b.Private.Photos[0].Data = strings.Repeat("A", 2800001) },
		"too many photos":  func(b *Booking) { b.Private.Photos = make([]BookingPhoto, 6) },
	}
	for name, change := range cases {
		t.Run(name, func(t *testing.T) {
			b := valid()
			change(b)
			if b.Validate(&start, 1200) == nil {
				t.Fatal("accepted invalid booking")
			}
		})
	}
}
