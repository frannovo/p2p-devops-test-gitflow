package main

import (
	"fmt"
	"net/http"
	"time"
)

func IndexHandler(w http.ResponseWriter, r *http.Request) {
	_, err := fmt.Fprintf(w, "Hello, you've requested: %s\n", r.URL.Path)
	if err != nil {
		fmt.Println("Error writing response:", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func HealthCheckHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, err := fmt.Fprint(w, "OK")
	if err != nil {
		fmt.Println("Error writing healthcheck response:", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func main() {
	http.HandleFunc("/", IndexHandler)
	http.HandleFunc("/healthz", HealthCheckHandler)
	fmt.Println("Web app running on localhost:3000")

	server := &http.Server{
		Addr:              ":3000",
		ReadHeaderTimeout: 30 * time.Second,
	}

	err := server.ListenAndServe()
	if err != nil {
		panic(err)
	}
}
