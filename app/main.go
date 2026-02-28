package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"sort"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"

	cache "github.com/victorspringer/http-cache"
	"github.com/victorspringer/http-cache/adapter/memory"

	_ "github.com/danielgtaylor/huma/v2/formats/cbor"
)

// Configuration constants
const (
	serverPort      = ":8888"
	httpTimeout     = 10 * time.Second
	cacheTTL        = 10 * time.Minute
	cacheCapacity   = 10_000_000 // 10MB
	cacheRefreshKey = "opn"
)

// Health represents the response of the "get health" operation.
type HealthOutput struct {
	Body struct {
		Status string `json:"status"`
	}
}

// Link represents a link with its information.
type Link struct {
	Id    int    `json:"id" doc:"Id of the resource"`
	Url   string `json:"url,omitempty" doc:"Url to search"`
	Links int    `json:"links" doc:"Number of the links finds"`
}

// Links response
type LinksOutput struct {
	Body struct {
		Links []Link `json:"links" doc:"Links to search"`
		Time  string `json:"time" doc:"Time take to search"`
	}
}

// URLs to analyze
var urls = []string{
	"https://go.dev",
	"https://www.python.org",
	"https://www.realpython.com",
	"https://nodejs.org",
	"https://www.facebook.com",
	"https://www.gitlab.com",
	"https://alvarolinarescabre.github.io",
	"https://www.mozilla.org",
	"https://www.github.com",
	"https://www.google.com",
}

// Precompiled variables for better performance
var (
	hrefPattern = regexp.MustCompile(`href="(http|https)://`)
	httpClient  = &http.Client{
		Timeout: httpTimeout,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 20,
			IdleConnTimeout:     60 * time.Second,
		},
	}
)

// getURL safely gets the content of a URL
func getURL(url string) (io.ReadCloser, error) {
	log.Printf("[getURL] Fetching URL: %s", url)
	start := time.Now()

	// Create a new request
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		log.Printf("[getURL] Error creating request for %s: %v", url, err)
		return nil, fmt.Errorf("error creating request: %w", err)
	}

	// Set the headers
	req.Header.Set("Connection", "Keep-Alive")
	req.Header.Set("Accept-Language", "es-ES")
	req.Header.Set("User-Agent", "Mozilla/5.0")

	// Use the global HTTP client with timeout
	res, err := httpClient.Do(req)
	if err != nil {
		log.Printf("[getURL] HTTP request failed for %s after %s: %v", url, time.Since(start), err)
		return nil, fmt.Errorf("error making HTTP request: %w", err)
	}

	log.Printf("[getURL] Response from %s: status=%d, duration=%s", url, res.StatusCode, time.Since(start))

	if res.StatusCode >= 400 {
		res.Body.Close()
		log.Printf("[getURL] Bad status code %d for %s", res.StatusCode, url)
		return nil, fmt.Errorf("bad status code: %d", res.StatusCode)
	}

	return res.Body, nil
}

// webScrapingCounter counts HTTPS and HTTP links in a text
func webScrapingCounter(data string) int {
	matches := hrefPattern.FindAllString(data, -1)
	if matches == nil {
		log.Printf("[webScrapingCounter] No href links found (data length: %d bytes)", len(data))
		return 0
	}
	log.Printf("[webScrapingCounter] Found %d href links (data length: %d bytes)", len(matches), len(data))
	return len(matches)
}

// Add GET / for health checks
func getHealthCheck(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID:   "get-health",
		Summary:       "Get health",
		Method:        http.MethodGet,
		Path:          "/",
		DefaultStatus: http.StatusOK,
	}, func(ctx context.Context, i *struct{}) (*HealthOutput, error) {
		log.Println("[health] Health check requested")
		resp := &HealthOutput{}
		resp.Body.Status = "ok"
		return resp, nil
	})

}

func getLinks(api huma.API) {
	// Register GET /v1/links
	huma.Register(api, huma.Operation{
		OperationID: "get-links",
		Method:      http.MethodGet,
		Path:        "/v1/links",
		Summary:     "Get links",
		Description: "Get links to 'https' and 'http' from 10 sites.",
		Tags:        []string{"Links"},
	}, func(ctx context.Context, input *struct{}) (*LinksOutput, error) {
		resp := &LinksOutput{}
		links := make([]Link, 0, len(urls))

		start := time.Now()

		log.Printf("[getLinks] Starting to search %d URLs...", len(urls))

		// Create a channel for results
		results := make(chan struct {
			link Link
			err  error
		}, len(urls))

		// Launch goroutines for each URL
		for i, url := range urls {
			log.Printf("[getLinks] Launching goroutine %d for %s", i, url)
			go func(index int, u string) {
				body, err := getURL(u)
				if err != nil {
					log.Printf("[getLinks] Error fetching URL %s (goroutine %d): %v", u, index, err)
					results <- struct {
						link Link
						err  error
					}{Link{}, err}
					return
				}
				defer body.Close()

				data, err := io.ReadAll(body)
				if err != nil {
					log.Printf("[getLinks] Error reading response from %s (goroutine %d): %v", u, index, err)
					results <- struct {
						link Link
						err  error
					}{Link{}, fmt.Errorf("error reading response from %s: %w", u, err)}
					return
				}

				count := webScrapingCounter(string(data))
				results <- struct {
					link Link
					err  error
				}{
					Link{
						Id:    index,
						Url:   u,
						Links: count,
					},
					nil,
				}
			}(i, url)
		}

		// Collect results
		var errors []error
		for i := 0; i < len(urls); i++ {
			result := <-results
			if result.err != nil {
				errors = append(errors, result.err)
				continue
			}
			links = append(links, result.link)
			log.Printf("[getLinks] Collected result: id=%d | url=%s | links=%d", result.link.Id, result.link.Url, result.link.Links)
		}

		// Sort results by ID to maintain consistent ordering
		sort.Slice(links, func(i, j int) bool {
			return links[i].Id < links[j].Id
		})

		resp.Body.Links = links
		timeElapsed := time.Since(start)
		resp.Body.Time = timeElapsed.String()

		log.Printf("[getLinks] Finished searching links: %d succeeded, %d failed. Took %s", len(links), len(errors), timeElapsed.String())
		// If there are errors, we log them but continue
		for _, err := range errors {
			log.Printf("[getLinks] Error during search: %v", err)
		}

		return resp, nil
	})
}

func getLink(api huma.API) {
	// Register GET /v1/link/{id}
	huma.Register(api, huma.Operation{
		OperationID: "get-link",
		Method:      http.MethodGet,
		Path:        "/v1/link/{id}",
		Summary:     "Get link",
		Description: "Get link to 'https' and 'http' search for one of 10 websites",
		Tags:        []string{"Links"},
	}, func(ctx context.Context, input *struct {
		Id int `path:"id" maxLength:"2" example:"0" doc:"Id of website from array"`
	}) (*LinksOutput, error) {
		resp := &LinksOutput{}
		start := time.Now()

		log.Printf("[getLink] Starting to search link for id=%d", input.Id)

		id := input.Id

		// Check if the id is between 0 and 9
		if id < 0 || id >= len(urls) {
			log.Printf("[getLink] Invalid id=%d requested (valid range: 0-%d)", id, len(urls)-1)
			return nil, fmt.Errorf("id must be between 0 and %d", len(urls)-1)
		}

		// Get the url from the urls array
		url := urls[id]
		log.Printf("[getLink] Resolved id=%d to URL: %s", id, url)

		// Get the response body
		body, err := getURL(url)
		if err != nil {
			log.Printf("[getLink] Failed to fetch URL %s: %v", url, err)
			return nil, err
		}
		defer body.Close()

		// Read the response body
		data, err := io.ReadAll(body)
		if err != nil {
			log.Printf("[getLink] Failed to read response body from %s: %v", url, err)
			return nil, fmt.Errorf("error reading response body: %w", err)
		}
		log.Printf("[getLink] Read %d bytes from %s", len(data), url)

		count := webScrapingCounter(string(data))

		link := []Link{
			{
				Id:    id,
				Url:   url,
				Links: count,
			},
		}

		timeElapsed := time.Since(start)
		resp.Body.Time = timeElapsed.String()
		resp.Body.Links = link

		log.Printf("[getLink] id: %d | url: %s | links found: %d | duration: %s", id, url, count, timeElapsed.String())

		return resp, nil
	})
}

// Create a new router & API
func main() {
	log.Println("[main] Initializing application...")

	// Create a new router & API
	router := chi.NewMux()
	log.Println("[main] Router created")

	// Initialize the cache
	log.Printf("[main] Initializing cache (capacity: %d bytes, TTL: %s)", cacheCapacity, cacheTTL)
	memcached, err := memory.NewAdapter(
		memory.AdapterWithAlgorithm(memory.LRU),
		memory.AdapterWithCapacity(cacheCapacity),
	)
	if err != nil {
		log.Fatalf("[main] Error creating cache adapter: %v", err)
	}

	cacheClient, err := cache.NewClient(
		cache.ClientWithAdapter(memcached),
		cache.ClientWithTTL(cacheTTL),
		cache.ClientWithRefreshKey(cacheRefreshKey),
	)
	if err != nil {
		log.Fatalf("[main] Error creating cache client: %v", err)
	}

	// Apply cache middleware to the router BEFORE registering routes
	router.Use(cacheClient.Middleware)
	log.Println("[main] Cache middleware applied")

	// Create the API after setting up middlewares
	api := humachi.New(router, huma.DefaultConfig("Get links to 'https' and 'http' from 10 sites.", "1.0.0"))
	log.Println("[main] Huma API created")

	// Register endpoints
	getHealthCheck(api)
	getLink(api)
	getLinks(api)
	log.Println("[main] All endpoints registered: GET /, GET /v1/link/{id}, GET /v1/links")

	log.Printf("[main] Starting server on port%s", serverPort)
	if err := http.ListenAndServe(serverPort, router); err != nil {
		log.Fatalf("[main] Server error: %v", err)
	}
}
