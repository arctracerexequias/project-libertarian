package http

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/service-marketplace/communication-service/internal/domain"
	"github.com/service-marketplace/shared-contracts/pkg/middleware"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		if origin == "" {
			return true
		}
		for _, allowed := range strings.Split(os.Getenv("WS_ALLOWED_ORIGINS"), ",") {
			if origin == strings.TrimSpace(allowed) {
				return true
			}
		}
		return false
	},
}

type chatClient struct {
	conn   *websocket.Conn
	userID string
	mu     sync.Mutex
}

type ChatHandler struct {
	service domain.ChatService
	clients map[string][]*chatClient // jobID -> connections
	mu      sync.Mutex
}

func NewChatHandler(service domain.ChatService) *ChatHandler {
	return &ChatHandler{
		service: service,
		clients: make(map[string][]*chatClient),
	}
}

func (h *ChatHandler) GetHistory(c *gin.Context) {
	jobID := c.Param("jobId")
	history, err := h.service.GetChatHistory(c.Request.Context(), jobID, middleware.GetUserID(c))
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "Chat unavailable for this user"})
		return
	}
	c.JSON(http.StatusOK, history)
}

func (h *ChatHandler) HandleWebSocket(c *gin.Context) {
	jobID := c.Query("jobId")
	if jobID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "jobId query parameter is required"})
		return
	}

	userID := middleware.GetUserID(c)
	if err := h.service.Authorize(c.Request.Context(), jobID, userID); err != nil {
		c.JSON(403, gin.H{"error": "Not a participant in this job"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade to websocket: %v", err)
		return
	}

	conn.SetReadLimit(16384)
	conn.SetReadDeadline(time.Now().Add(75 * time.Second))
	conn.SetPongHandler(func(string) error { return conn.SetReadDeadline(time.Now().Add(75 * time.Second)) })
	done := make(chan struct{})
	defer close(done)
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				return
			case <-ticker.C:
				if err := conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(5*time.Second)); err != nil {
					conn.Close()
					return
				}
			}
		}
	}()
	h.addClient(jobID, userID, conn)
	defer h.removeClient(jobID, conn)

	for {
		var req struct {
			Type    string `json:"type"` // MESSAGE, TYPING
			Content string `json:"content"`
		}
		err := conn.ReadJSON(&req)
		if err != nil {
			log.Printf("WS Read error: %v", err)
			break
		}

		conn.SetReadDeadline(time.Now().Add(75 * time.Second))
		if err := h.service.Authorize(c.Request.Context(), jobID, userID); err != nil {
			break
		}
		if req.Type == "TYPING" {
			// Broadcast typing status without saving to DB
			h.broadcast(jobID, &domain.Message{
				JobID:    jobID,
				SenderID: userID,
				Content:  "TYPING", // Metadata
			})
			continue
		}

		msg, err := h.service.SendMessage(c.Request.Context(), jobID, userID, req.Content)
		if err != nil {
			log.Printf("Failed to save message: %v", err)
			continue
		}

		h.broadcast(jobID, msg)
	}
}

func (h *ChatHandler) addClient(jobID, userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[jobID] = append(h.clients[jobID], &chatClient{conn: conn, userID: userID})
}

func (h *ChatHandler) removeClient(jobID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	clients := h.clients[jobID]
	for i, c := range clients {
		if c.conn == conn {
			h.clients[jobID] = append(clients[:i], clients[i+1:]...)
			break
		}
	}
	conn.Close()
}

func (h *ChatHandler) broadcast(jobID string, msg *domain.Message) {
	h.mu.Lock()
	clients := append([]*chatClient(nil), h.clients[jobID]...)
	h.mu.Unlock()
	for _, client := range clients {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		err := h.service.Authorize(ctx, jobID, client.userID)
		cancel()
		if err != nil {
			client.conn.Close()
			continue
		}
		client.mu.Lock()
		client.conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
		err = client.conn.WriteJSON(msg)
		client.mu.Unlock()
		if err != nil {
			client.conn.Close()
		}
	}
}
