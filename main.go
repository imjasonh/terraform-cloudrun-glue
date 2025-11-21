package main

import "net/http"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("hello from regional-gce-service"))
	})
	http.ListenAndServe(":8080", nil)
}
