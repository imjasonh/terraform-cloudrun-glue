package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"golang.org/x/oauth2"
	"google.golang.org/api/idtoken"
)

func main() {
	backend := os.Getenv("BACKEND_ADDRESS")

	ctx := context.Background()
	ts, err := idtoken.NewTokenSource(ctx, backend)
	if err != nil {
		log.Fatalf("google identity token source: %v", err)
	}
	client := oauth2.NewClient(ctx, oauth2.ReuseTokenSource(nil, ts))

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		resp, err := client.Get(backend)
		if err != nil {
			http.Error(w, "Error contacting backend: "+err.Error(), http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()
		_, _ = fmt.Fprintln(w, "backend says:")
		_, _ = io.Copy(w, resp.Body)
	})
	http.ListenAndServe(":8080", nil)
}
