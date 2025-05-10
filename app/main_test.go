package main

import (
	"testing"

	"github.com/danielgtaylor/huma/v2/humatest"
)

func TestGetHealthCheck(t *testing.T) {
	_, api := humatest.New(t)

	getHealthCheck(api)

	resp := api.Get("/")

	if resp.Code != 200 {
		t.Fatalf("Unexpected status code: %d", resp.Code)
	}
}

func TestGetLink(t *testing.T) {
	_, api := humatest.New(t)

	getLink(api)

	resp := api.Get("/v1/link/0", map[string]any{
		"id":    0,
		"url":   "https://go.dev",
		"links": 67,
	})

	if resp.Code != 200 {
		t.Fatalf("Unexpected status code: %d", resp.Code)
	}
}

func TestGetLinks(t *testing.T) {
	// Define the URLs to scrape
	_, api := humatest.New(t)

	getLinks(api)
	resp := api.Get("/v1/links")

	if resp.Code != 200 {
		t.Fatalf("Unexpected status code: %d", resp.Code)
	}
}

func TestGetLinkError(t *testing.T) {
	_, api := humatest.New(t)

	getLink(api)

	resp := api.Get("/v1/link/10")

	if resp.Code != 500 {
		t.Fatalf("Unexpected status code: %d", resp.Code)
	}
}
