package main

import (
	"context"
	"fmt"
	"net/http"

	"cloud.google.com/go/compute/metadata"
)

func main() {
	region, err := metadata.ZoneWithContext(context.Background())
	if err != nil {
		region = "unknown"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "hello from regional-gce-service in region:", region)
	})
	http.ListenAndServe(":8080", nil)
}
