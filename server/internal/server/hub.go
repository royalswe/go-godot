package server

import (
	"log"
	"net/http"
	"server/pkg/packets"
)

type ClientInterfacer interface {
	Id() uint64
	Initialize(id uint64)
	ProcessMessage(senderId uint64, msg packets.Msg)
	// Puts data from this client into the write pump
	SocketSend(message packets.Msg)
	// Puts dara from another client into the write pump
	SocketSendAs(message packets.Msg, senderId uint64)
	// Forward  message to another client for processing
	PassToPeer(message packets.Msg, peerId uint64)
	// Forward message to all other clients for processing
	Broadcast(message packets.Msg)
	// Pump data from the connected socket directly to the client
	ReadPump()
	// Pump data from the client directly to the connected socket
	WritePump()
	// Close the connection and clean up
	Close(reason string)
}

// The hub is the central point of communication between all connected clients
type Hub struct {
	Clients map[uint64]ClientInterfacer
	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChan chan *packets.Packet
	// Clients in this channel will be registered with the hub
	RegisterChan chan ClientInterfacer
	// Clients in this channel will be unregistered with the hub
	UnregisterChan chan ClientInterfacer
}

func NewHub() *Hub {
	return &Hub{
		Clients:        make(map[uint64]ClientInterfacer),
		BroadcastChan:  make(chan *packets.Packet),
		RegisterChan:   make(chan ClientInterfacer),
		UnregisterChan: make(chan ClientInterfacer),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.RegisterChan:
			client.Initialize(uint64(len(h.Clients)))
			log.Println("Client registered")
		case client := <-h.UnregisterChan:
			h.Clients[client.Id()] = nil
			log.Println("Client unregistered")
		case packet := <-h.BroadcastChan:
			for id, client := range h.Clients {
				if id != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Msg)
				}
			}
		}
	}
}

func (h *Hub) Serve(getNewClient func(*Hub, http.ResponseWriter, *http.Request) (ClientInterfacer, error), writer http.ResponseWriter, request *http.Request) {
	log.Println("New connection", request.RemoteAddr)
	client, err := getNewClient(h, writer, request)

	if err != nil {
		log.Println("Failed to create client", err)
		return
	}

	h.RegisterChan <- client

	go client.WritePump()
	go client.ReadPump()
}
