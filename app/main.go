package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
	"sync"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"

	cache "github.com/victorspringer/http-cache"
	"github.com/victorspringer/http-cache/adapter/memory"

	_ "github.com/danielgtaylor/huma/v2/formats/cbor"
)

// Health represents the response of the "get health" operation.
type HealthOutput struct {
	Body struct {
		Status string `json:"status"`
	}
}

// Link response
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

// 10 Websites and search https and http
var urls = []string{
	"https://go.dev",
	"https://www.paradigmadigital.com",
	"https://www.realpython.com",
	"https://www.lapatilla.com",
	"https://www.facebook.com",
	"https://www.gitlab.com",
	"https://www.youtube.com",
	"https://www.mozilla.org",
	"https://www.github.com",
	"https://www.google.com",
}

func getURL(url string) io.ReadCloser {
	// Create a new request
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		fmt.Printf("client: could not create request: %s\n", err)
		os.Exit(1)
	}

	// Set the headers
	req.Header.Set("Connection", "Keep-Alive")
	req.Header.Set("Accept-Language", "es-ES")
	req.Header.Set("User-Agent", "Mozilla/5.0")

	// Create a new HTTP client
	client := &http.Client{}
	// Set a timeout for the request
	client.Timeout = 10 * time.Second
	// Send the request
	res, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Printf("client: error making http request: %s\n", err)
		os.Exit(1)
	}

	return res.Body
}

func webScrapingCounter(data string) int {
	count := 0
	pattern := "href=\"(http|https)://"
	re, _ := regexp.Compile(pattern)

	matches := re.FindAllString(string(data), -1)

	if matches != nil {
		count += len(matches)
	}

	return count
}

// Add GET / for health checks
// This endpoint will return a 200 OK response with a JSON body
// containing the status of the service.
// This is useful for health checks and monitoring.
func getHealthCheck(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID:   "get-health",
		Summary:       "Get health",
		Method:        http.MethodGet,
		Path:          "/",
		DefaultStatus: http.StatusOK,
	}, func(ctx context.Context, i *struct{}) (*HealthOutput, error) {
		resp := &HealthOutput{}
		resp.Body.Status = "ok"
		return resp, nil
	})

}

func getLinks(api huma.API) {

	links := []Link{}

	// Register GET /v1/links
	// This endpoint will search for links in the 10 websites
	huma.Register(api, huma.Operation{
		OperationID: "get-links",
		Method:      http.MethodGet,
		Path:        "/v1/links",
		Summary:     "Get links",
		Description: "Get links to 'https' and 'http' from 10 sites.",
		Tags:        []string{"Links"},
	}, func(ctx context.Context, input *struct{}) (*LinksOutput, error) {
		resp := &LinksOutput{}

		start := time.Now()

		fmt.Println("Starting to search links...")

		// Set a callback for when a visited HTML element is found
		var wg = &sync.WaitGroup{}

		for index, url := range urls {

			wg.Add(1)
			func(url string) {
				defer wg.Done()

				// Get the response body
				body := getURL(url)
				defer body.Close()

				// Read the response body
				data, err := io.ReadAll(body)
				if err != nil {
					fmt.Printf("client: error reading response body: %s\n", err)
					os.Exit(1)
				}

				count := webScrapingCounter(string(data))

				links = append(links, Link{
					Id:    index,
					Url:   url,
					Links: count,
				})
				fmt.Printf("id: %d | url: %s | links: %d\n", index, url, count)
				resp.Body.Links = links
			}(url)
		}
		wg.Wait()

		timeElapsed := time.Since(start)
		resp.Body.Time = timeElapsed.String()

		fmt.Printf("Finished searching links. Took %s\n", timeElapsed.String())
		links = []Link{}

		return resp, nil
	})
}

func getLink(api huma.API) {

	link := make([]Link, 0)

	// Register GET /v1/link/{id}
	// This endpoint will search for link in only one of 10 websites
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

		fmt.Println("Starting to search link...")

		id := input.Id

		// Check if the id is between 0 and 9
		if id < 0 || id > 9 {
			return nil, fmt.Errorf("id must be between 0 and 9")
		}
		// Get the url from the urls array
		url := urls[id]

		// Get the response body
		body := getURL(url)
		defer body.Close()

		// Read the response body
		data, err := io.ReadAll(body)
		if err != nil {
			fmt.Printf("client: error reading response body: %s\n", err)
			os.Exit(1)
		}

		count := webScrapingCounter(string(data))

		timeElapsed := time.Since(start)

		link = append(link, Link{
			Id:    id,
			Url:   urls[id],
			Links: count,
		})

		resp.Body.Time = timeElapsed.String()

		resp.Body.Links = link
		fmt.Printf("id: %d | url: %s | link: %d\n", id, urls[id], count)

		fmt.Printf("Finished searching link. Take %s\n", timeElapsed.String())

		link = []Link{}

		return resp, nil
	})
}

// Create a new router & API
func main() {
	// Create a new router & API
	router := chi.NewMux()
	api := humachi.New(router, huma.DefaultConfig("Get links to 'https' and 'http' from 10 sites.", "1.0.0"))

	// Create a new cache
	var cacheClient *cache.Client

	// Initialize the cache
	// This function will create a new cache client using the memory adapter
	// and set the default TTL to 10 minutes.
	// It will also set the refresh key to "opn".
	// The cache will use the LRU algorithm and a capacity of 10MB.
	memcached, err := memory.NewAdapter(
		memory.AdapterWithAlgorithm(memory.LRU),
		memory.AdapterWithCapacity(10000000),
	)
	if err != nil {
		log.Fatal(err)
	}

	cacheClient, err = cache.NewClient(
		cache.ClientWithAdapter(memcached),
		cache.ClientWithTTL(10*time.Minute),
		cache.ClientWithRefreshKey("opn"),
	)
	if err != nil {
		log.Fatal(err)
	}

	// Create a new cache handler
	handler := http.HandlerFunc(http.DefaultServeMux.ServeHTTP)

	// Set the cache handler
	cacheHandler := cacheClient.Middleware(handler)

	// Create a new router
	wg := sync.WaitGroup{}
	wg.Add(3)
	// Call functions
	go func() {
		defer wg.Done()
		getHealthCheck(api)
	}()

	go func() {
		defer wg.Done()
		go getLink(api)

	}()

	go func() {
		defer wg.Done()
		go getLinks(api)

	}()

	wg.Wait()

	fmt.Printf("Starting server on port 8888\n")

	http.Handle("/v1/links", cacheHandler)
	http.Handle("/v1/link/{id}", cacheHandler)
	http.ListenAndServe(":8888", router)
}
