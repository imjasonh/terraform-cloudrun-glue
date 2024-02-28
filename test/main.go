package main

import (
	"encoding/json"
	"net/http"

	"github.com/chainguard-dev/terraform-infra-common/pkg/httpmetrics"
	"github.com/google/go-github/github"
)

func main() {
	http.DefaultTransport = httpmetrics.Transport
	c := github.NewClient(&http.Client{Transport: http.DefaultTransport})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		issues, _, err := c.Issues.ListByRepo(ctx, "chainguard-dev", "terraform-infra-common", nil)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(issues)
	})
	http.ListenAndServe(":8080", nil)
}
