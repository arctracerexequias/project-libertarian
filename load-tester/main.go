package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"sync"
	"time"
)

const (
	baseURL = "http://localhost:8080/api/v1"
	concurrencyProviders = 100
	concurrencyCustomers = 50
	concurrencyBidding   = 20
)

type Metrics struct {
	mu           sync.Mutex
	SuccessCount int
	ErrorCount   int
}

func (m *Metrics) IncSuccess() {
	m.mu.Lock()
	m.SuccessCount++
	m.mu.Unlock()
}

func (m *Metrics) IncError() {
	m.mu.Lock()
	m.ErrorCount++
	m.mu.Unlock()
}

var metrics = &Metrics{}

func simulateProviderTelemetry(id int, wg *sync.WaitGroup) {
	defer wg.Done()
	providerID := fmt.Sprintf("sim-provider-%d", id)
	client := &http.Client{Timeout: 5 * time.Second}

	for {
		data := map[string]interface{}{
			"provider_id": providerID,
			"lat":         14.5 + rand.Float64(),
			"lng":         121.0 + rand.Float64(),
		}
		body, _ := json.Marshal(data)
		resp, err := client.Post(baseURL+"/dispatch/location", "application/json", bytes.NewBuffer(body))
		if err != nil || resp.StatusCode != http.StatusOK {
			metrics.IncError()
		} else {
			metrics.IncSuccess()
			resp.Body.Close()
		}
		time.Sleep(1 * time.Second)
	}
}

func simulateCustomerBrowsing(wg *sync.WaitGroup) {
	defer wg.Done()
	client := &http.Client{Timeout: 5 * time.Second}

	for {
		resp, err := client.Get(baseURL + "/marketplace/jobs/")
		if err != nil || resp.StatusCode != http.StatusOK {
			metrics.IncError()
		} else {
			metrics.IncSuccess()
			resp.Body.Close()
		}
		time.Sleep(2 * time.Second)
	}
}

func simulateProviderBidding(wg *sync.WaitGroup) {
	defer wg.Done()
	client := &http.Client{Timeout: 5 * time.Second}

	// First, let's create a dummy job to bid on if needed, but we'll assume jobs exist
	for {
		data := map[string]interface{}{
			"amount":         100.0 + rand.Float64()*500,
			"estimated_time": "2 hours",
			"message":        "I can do this!",
		}
		body, _ := json.Marshal(data)
		// We use a dummy ID or attempt to bid on a range
		jobID := "proto-job-id" 
		resp, err := client.Post(baseURL+"/marketplace/jobs/"+jobID+"/bids", "application/json", bytes.NewBuffer(body))
		if err != nil || (resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK) {
			metrics.IncError()
		} else {
			metrics.IncSuccess()
			resp.Body.Close()
		}
		time.Sleep(5 * time.Second)
	}
}

func main() {
	fmt.Printf("🚀 Starting Load Simulation against %s\n", baseURL)
	fmt.Printf("Simulating %d providers (telemetry), %d customers (browsing), %d bidders...\n", 
		concurrencyProviders, concurrencyCustomers, concurrencyBidding)

	var wg sync.WaitGroup

	for i := 0; i < concurrencyProviders; i++ {
		wg.Add(1)
		go simulateProviderTelemetry(i, &wg)
	}

	for i := 0; i < concurrencyCustomers; i++ {
		wg.Add(1)
		go simulateCustomerBrowsing(&wg)
	}

	for i := 0; i < concurrencyBidding; i++ {
		wg.Add(1)
		go simulateProviderBidding(&wg)
	}

	// Metrics reporter
	go func() {
		for {
			time.Sleep(5 * time.Second)
			metrics.mu.Lock()
			fmt.Printf("[%s] Metrics -> Success: %d | Errors: %d | Throughput: %.2f req/s\n",
				time.Now().Format("15:04:05"),
				metrics.SuccessCount,
				metrics.ErrorCount,
				float64(metrics.SuccessCount+metrics.ErrorCount)/5.0)
			metrics.SuccessCount = 0
			metrics.ErrorCount = 0
			metrics.mu.Unlock()
		}
	}()

	wg.Wait()
}
