package main

import (
	"flag"
	"fmt"
	"net/http"
	"server/internal/server"
	"server/internal/server/clients"
)

var (
	port = flag.Int("port", 8080, "The port to listen on")
)

func main() {
	flag.Parse()

	// Create a new hub
	hub := server.NewHub()

	// Define the handlers for the websocket connnections
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		hub.Serve(clients.NewWebSocketClient, w, r)
	})

	go hub.Run()

	addr := fmt.Sprintf(":%d", *port)
	err := http.ListenAndServe(addr, nil)

	if err != nil {
		panic(err)
	}
}
