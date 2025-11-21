package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

func main() {
	backend := os.Getenv("BACKEND_ADDRESS")
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		resp, err := http.Get("http://" + backend)
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
