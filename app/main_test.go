package main

import (
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/danielgtaylor/huma/v2/humatest"
)

// TestGetHealthCheck verifies the health endpoint returns a 200 status
func TestGetHealthCheck(t *testing.T) {
	// Setup
	_, api := humatest.New(t)
	getHealthCheck(api)

	// Execute
	resp := api.Get("/")

	// Verify
	if resp.Code != http.StatusOK {
		t.Fatalf("Expected status code %d but got %d", http.StatusOK, resp.Code)
	}

	// Check response body
	if !strings.Contains(string(resp.Body.Bytes()), "ok") {
		t.Fatalf("Expected body to contain 'ok', got: %s", resp.Body.String())
	}
}

// TestGetLink tests the single link endpoint with valid ID
func TestGetLink(t *testing.T) {
	// Setup
	_, api := humatest.New(t)
	getLink(api)

	// Execute
	resp := api.Get("/v1/link/0", map[string]any{
		"id": 0,
	})

	// Verify
	if resp.Code != http.StatusOK {
		t.Fatalf("Expected status code %d but got %d", http.StatusOK, resp.Code)
	}

	// Check response contains expected fields
	body := string(resp.Body.Bytes())
	if !strings.Contains(body, "links") || !strings.Contains(body, "time") {
		t.Fatalf("Response missing expected fields: %s", body)
	}
}

// TestGetLinks tests the multiple links endpoint
func TestGetLinks(t *testing.T) {
	// Setup
	_, api := humatest.New(t)
	getLinks(api)

	// Execute
	resp := api.Get("/v1/links")

	// Verify
	if resp.Code != http.StatusOK {
		t.Fatalf("Expected status code %d but got %d", http.StatusOK, resp.Code)
	}

	// Check response contains expected fields
	body := string(resp.Body.Bytes())
	if !strings.Contains(body, "links") || !strings.Contains(body, "time") {
		t.Fatalf("Response missing expected fields: %s", body)
	}
}

// TestGetLinkError tests the error case with invalid ID
func TestGetLinkError(t *testing.T) {
	// Setup
	_, api := humatest.New(t)
	getLink(api)

	// Execute - test with ID out of range
	resp := api.Get("/v1/link/10")

	// Verify
	if resp.Code != http.StatusInternalServerError {
		t.Fatalf("Expected error status code %d but got %d", http.StatusInternalServerError, resp.Code)
	}
}

// TestGetLinkNegativeID tests the error case with negative ID
func TestGetLinkNegativeID(t *testing.T) {
	// Setup
	_, api := humatest.New(t)
	getLink(api)

	// Execute - test with negative ID
	resp := api.Get("/v1/link/-1")

	// Verify
	if resp.Code != http.StatusInternalServerError {
		t.Fatalf("Expected error status code %d but got %d", http.StatusInternalServerError, resp.Code)
	}
}

// TestWebScrapingCounter tests the link counting function
func TestWebScrapingCounter(t *testing.T) {
	// Test cases
	testCases := []struct {
		name     string
		input    string
		expected int
	}{
		{
			name:     "Empty string",
			input:    "",
			expected: 0,
		},
		{
			name:     "No links",
			input:    "Hello world",
			expected: 0,
		},
		{
			name:     "One HTTP link",
			input:    `<a href="http://example.com">Example</a>`,
			expected: 1,
		},
		{
			name:     "One HTTPS link",
			input:    `<a href="https://example.com">Example</a>`,
			expected: 1,
		},
		{
			name:     "Multiple links",
			input:    `<a href="https://example.com">Example</a><a href="http://test.com">Test</a>`,
			expected: 2,
		},
		{
			name:     "Invalid links format",
			input:    `<a href=https://example.com>Example</a>`,
			expected: 0,
		},
	}

	// Run test cases
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			count := webScrapingCounter(tc.input)
			if count != tc.expected {
				t.Errorf("Expected %d links but got %d for input: %s", tc.expected, count, tc.input)
			}
		})
	}
}

// MockReadCloser implements io.ReadCloser for testing
type MockReadCloser struct {
	io.Reader
	closeFunc func() error
}

func (m MockReadCloser) Close() error {
	if m.closeFunc != nil {
		return m.closeFunc()
	}
	return nil
}

// TestGetURL tests the URL fetching function
func TestGetURL(t *testing.T) {
	// Skip this test in CI environments or when running quick tests
	if testing.Short() {
		t.Skip("Skipping URL test in short mode")
	}

	// Test with a reliable URL
	url := "https://www.google.com"
	body, err := getURL(url)

	// Clean up
	if body != nil {
		defer body.Close()
	}

	// Verify
	if err != nil {
		t.Fatalf("getURL failed: %v", err)
	}

	if body == nil {
		t.Fatal("Expected non-nil body")
	}

	// Read some content to verify
	data, err := io.ReadAll(body)
	if err != nil {
		t.Fatalf("Failed to read body: %v", err)
	}

	if len(data) == 0 {
		t.Fatal("Expected non-empty response")
	}
}

// TestGetURLError tests error handling in getURL function
func TestGetURLError(t *testing.T) {
	// Test with an invalid URL
	url := "https://this-domain-does-not-exist-123456789.example"
	body, err := getURL(url)

	// Clean up
	if body != nil {
		defer body.Close()
	}

	// Verify
	if err == nil {
		t.Fatal("Expected error from non-existent domain")
	}
}

// Benchmark the webScrapingCounter function
func BenchmarkWebScrapingCounter(b *testing.B) {
	testHTML := `<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
</head>
<body>
    <a href="https://example.com">Example</a>
    <a href="https://google.com">Google</a>
    <a href="http://github.com">GitHub</a>
    <a href="https://golang.org">Go</a>
</body>
</html>`

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		webScrapingCounter(testHTML)
	}
}

// Benchmark the concurrent link processing
func BenchmarkConcurrentProcessing(b *testing.B) {
	// Create mock data
	mockData := make([]string, 10)
	for i := 0; i < 10; i++ {
		mockData[i] = "<html><body><a href=\"https://example.com\">Example</a></body></html>"
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		results := make(chan struct {
			link Link
			err  error
		}, len(mockData))

		for j, data := range mockData {
			go func(index int, htmlData string) {
				count := webScrapingCounter(htmlData)
				results <- struct {
					link Link
					err  error
				}{
					Link{
						Id:    index,
						Url:   "https://example.com",
						Links: count,
					},
					nil,
				}
			}(j, data)
		}

		for j := 0; j < len(mockData); j++ {
			<-results
		}
	}
}

// Test HTTP client timeout behavior without mutating the global httpClient
func TestHTTPClient(t *testing.T) {
	// Create a local client with lower timeout for testing
	client := &http.Client{
		Timeout: 500 * time.Millisecond,
	}

	// Test that timeout works
	req, err := http.NewRequest(http.MethodGet, "http://example.com:81", nil)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	start := time.Now()
	_, err = client.Do(req) // Non-standard port to force timeout
	elapsed := time.Since(start)

	// We expect a timeout error
	if err == nil {
		t.Fatal("Expected timeout error")
	}

	// Check if elapsed time is close to timeout
	if elapsed < 400*time.Millisecond || elapsed > 700*time.Millisecond {
		t.Fatalf("Expected timeout after about 500ms, got: %v", elapsed)
	}
}
