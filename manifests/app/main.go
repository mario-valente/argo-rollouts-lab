package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"
)

var (
	requestCount    uint64
	errorCount      uint64
	version         = getEnv("APP_VERSION", "v1")
	color           = getEnv("APP_COLOR", "blue")
	errorRate       = getEnvFloat("ERROR_RATE", 0.0)
	latencyMs       = getEnvInt("LATENCY_MS", 0)
	latencyVariance = getEnvInt("LATENCY_VARIANCE", 0)
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if f, err := strconv.ParseFloat(value, 64); err == nil {
			return f
		}
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return defaultValue
}

type HealthResponse struct {
	Status    string `json:"status"`
	Version   string `json:"version"`
	Color     string `json:"color"`
	Hostname  string `json:"hostname"`
	Timestamp string `json:"timestamp"`
}

type MetricsResponse struct {
	TotalRequests uint64  `json:"total_requests"`
	ErrorCount    uint64  `json:"error_count"`
	ErrorRate     float64 `json:"error_rate"`
	Version       string  `json:"version"`
}

func main() {
	rand.Seed(time.Now().UnixNano())

	http.HandleFunc("/", handleRoot)
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/ready", handleReady)
	http.HandleFunc("/metrics", handleMetrics)
	http.HandleFunc("/api/info", handleInfo)
	http.HandleFunc("/api/process", handleProcess)
	http.HandleFunc("/api/heavy", handleHeavyOperation)

	port := getEnv("PORT", "8080")
	log.Printf("🚀 Starting server version %s (color: %s) on port %s", version, color, port)
	log.Printf("📊 Error rate: %.2f%%, Base latency: %dms (±%dms)", errorRate*100, latencyMs, latencyVariance)

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func simulateLatency() {
	if latencyMs > 0 {
		variance := 0
		if latencyVariance > 0 {
			variance = rand.Intn(latencyVariance*2) - latencyVariance
		}
		time.Sleep(time.Duration(latencyMs+variance) * time.Millisecond)
	}
}

func shouldError() bool {
	return rand.Float64() < errorRate
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	atomic.AddUint64(&requestCount, 1)
	simulateLatency()

	if shouldError() {
		atomic.AddUint64(&errorCount, 1)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	hostname, _ := os.Hostname()
	html := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <title>Demo App - %s</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
        }
        .container {
            text-align: center;
            background: white;
            padding: 60px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 500px;
        }
        .version {
            font-size: 72px;
            font-weight: bold;
            color: %s;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        .info {
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
        .badge {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            background: %s;
            color: white;
            font-weight: bold;
            margin: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="version">%s</div>
        <div class="info">
            <span class="badge">%s</span>
            <p>Hostname: %s</p>
            <p>Requests: %d | Errors: %d</p>
        </div>
    </div>
</body>
</html>
`, version, color, color, version, color, hostname, atomic.LoadUint64(&requestCount), atomic.LoadUint64(&errorCount))

	w.Header().Set("Content-Type", "text/html")
	fmt.Fprint(w, html)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	response := HealthResponse{
		Status:    "healthy",
		Version:   version,
		Color:     color,
		Hostname:  hostname,
		Timestamp: time.Now().Format(time.RFC3339),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func handleReady(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ready")
}

func handleMetrics(w http.ResponseWriter, r *http.Request) {
	total := atomic.LoadUint64(&requestCount)
	errors := atomic.LoadUint64(&errorCount)

	var rate float64
	if total > 0 {
		rate = float64(errors) / float64(total) * 100
	}

	// Prometheus format metrics
	metrics := fmt.Sprintf(`# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{version="%s",color="%s"} %d

# HELP http_errors_total Total number of HTTP errors
# TYPE http_errors_total counter
http_errors_total{version="%s",color="%s"} %d

# HELP http_error_rate Current error rate percentage
# TYPE http_error_rate gauge
http_error_rate{version="%s",color="%s"} %.2f

# HELP app_info Application information
# TYPE app_info gauge
app_info{version="%s",color="%s"} 1
`, version, color, total, version, color, errors, version, color, rate, version, color)

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprint(w, metrics)
}

func handleInfo(w http.ResponseWriter, r *http.Request) {
	atomic.AddUint64(&requestCount, 1)
	simulateLatency()

	if shouldError() {
		atomic.AddUint64(&errorCount, 1)
		http.Error(w, `{"error": "Internal Server Error"}`, http.StatusInternalServerError)
		return
	}

	hostname, _ := os.Hostname()
	response := map[string]interface{}{
		"version":   version,
		"color":     color,
		"hostname":  hostname,
		"timestamp": time.Now().Format(time.RFC3339),
		"requests":  atomic.LoadUint64(&requestCount),
		"errors":    atomic.LoadUint64(&errorCount),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func handleProcess(w http.ResponseWriter, r *http.Request) {
	atomic.AddUint64(&requestCount, 1)
	simulateLatency()

	if shouldError() {
		atomic.AddUint64(&errorCount, 1)
		http.Error(w, `{"error": "Processing failed"}`, http.StatusInternalServerError)
		return
	}

	// Simulate some processing
	time.Sleep(time.Duration(rand.Intn(50)) * time.Millisecond)

	response := map[string]interface{}{
		"status":    "processed",
		"version":   version,
		"duration":  fmt.Sprintf("%dms", rand.Intn(50)),
		"timestamp": time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func handleHeavyOperation(w http.ResponseWriter, r *http.Request) {
	atomic.AddUint64(&requestCount, 1)

	// Simulate heavy operation with more latency
	time.Sleep(time.Duration(200+rand.Intn(300)) * time.Millisecond)
	simulateLatency()

	if shouldError() {
		atomic.AddUint64(&errorCount, 1)
		http.Error(w, `{"error": "Heavy operation failed"}`, http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"status":    "completed",
		"operation": "heavy",
		"version":   version,
		"timestamp": time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
