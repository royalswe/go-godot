package server

import (
	"context"
	"database/sql"
	_ "embed"
	"log"
	"math/rand"
	"net/http"
	"server/internal/server/db"
	"server/internal/server/objects"
	"server/pkg/packets"
	"time"

	_ "modernc.org/sqlite"
)

const MaxSpores = 1000

// Embed the database schema to be used when creating the database tables
//
//go:embed db/config/schema.sql
var schemaGenSql string

type SharedGameObjects struct {
	Players *objects.SharedCollection[*objects.Player]
	Spores  *objects.SharedCollection[*objects.Spore]
}

// A structure for a state machine to process the client's messages
type ClientStateHandler interface {
	Name() string
	// Inject the cllient into the state handler
	SetClient(client ClientInterfacer)
	OnEnter()
	HandleMessage(senderId uint64, msg packets.Msg)
	// Cleanuo the state handler and perform any last action
	OnExit()
}

// A structure for db transactions context
type DbTx struct {
	Ctx     context.Context
	Queries *db.Queries
}

func (h *Hub) NewDbTx() *DbTx {
	return &DbTx{
		Ctx:     context.Background(),
		Queries: db.New(h.dbPool),
	}
}

type ClientInterfacer interface {
	Id() uint64
	Initialize(id uint64)
	SetState(newState ClientStateHandler)
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

	SharedGameObjects() *SharedGameObjects
	// Close the connection and clean up
	Close(reason string)
	// A reference to the db transaction context for this client
	DbTx() *DbTx
}

// The hub is the central point of communication between all connected clients
type Hub struct {
	Clients *objects.SharedCollection[ClientInterfacer]
	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChan chan *packets.Packet
	// Clients in this channel will be registered with the hub
	RegisterChan chan ClientInterfacer
	// Clients in this channel will be unregistered with the hub
	UnregisterChan    chan ClientInterfacer
	SharedGameObjects *SharedGameObjects
	// Database connection pool
	dbPool *sql.DB
}

func NewHub() *Hub {
	dbPool, err := sql.Open("sqlite", "db.sqlite")
	if err != nil {
		log.Fatal(err)
	}
	return &Hub{
		Clients:        objects.NewSharedCollection[ClientInterfacer](),
		BroadcastChan:  make(chan *packets.Packet),
		RegisterChan:   make(chan ClientInterfacer),
		UnregisterChan: make(chan ClientInterfacer),
		SharedGameObjects: &SharedGameObjects{
			Players: objects.NewSharedCollection[*objects.Player](),
			Spores:  objects.NewSharedCollection[*objects.Spore](),
		},
		dbPool: dbPool,
	}
}

func (h *Hub) Run() {
	log.Println("Init db")
	if _, err := h.dbPool.ExecContext(context.Background(), schemaGenSql); err != nil {
		log.Fatal(err)
	}

	for i := 0; i < MaxSpores; i++ {
		h.SharedGameObjects.Spores.Add(h.NewSpore())
	}

	go h.replenishSporesLoop(5 * time.Second)

	for {
		select {
		case client := <-h.RegisterChan:
			client.Initialize(h.Clients.Add(client))
			log.Println("Client registered")
		case client := <-h.UnregisterChan:
			h.Clients.Remove(client.Id())
			log.Println("Client unregistered")
		case packet := <-h.BroadcastChan:
			h.Clients.ForEach(func(clientId uint64, client ClientInterfacer) {
				if clientId != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Msg)
				}
			})
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

func (h *Hub) NewSpore() *objects.Spore {
	sporeRadius := max(10+rand.NormFloat64()*3, 5)
	x, y := objects.SpawnCoords(sporeRadius, h.SharedGameObjects.Players, h.SharedGameObjects.Spores)
	return &objects.Spore{
		X:      x,
		Y:      y,
		Radius: sporeRadius,
	}
}

func (h *Hub) replenishSporesLoop(rate time.Duration) {
	ticker := time.NewTicker(rate)
	defer ticker.Stop()
	for range ticker.C {
		sporesRemaining := h.SharedGameObjects.Spores.Len()
		diff := MaxSpores - sporesRemaining

		if diff <= 0 {
			continue
		}

		log.Println("%d spores remaining, going to replenish %d", sporesRemaining, diff)
		for i := 0; i < min(diff, 10); i++ {
			spore := h.NewSpore()
			h.SharedGameObjects.Spores.Add(spore)
			h.BroadcastChan <- &packets.Packet{
				SenderId: 0,
				Msg:      packets.NewSpore(0, spore),
			}

			time.Sleep(100 * time.Millisecond)
		}
	}
}
