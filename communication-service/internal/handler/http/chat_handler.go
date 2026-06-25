package http

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/service-marketplace/communication-service/internal/domain"
	"github.com/service-marketplace/shared-contracts/pkg/middleware"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Prototype only
	},
}

type ChatHandler struct {
	service domain.ChatService
	clients map[string][]*websocket.Conn // jobID -> connections
	mu      sync.Mutex
}

func NewChatHandler(service domain.ChatService) *ChatHandler {
	return &ChatHandler{
		service: service,
		clients: make(map[string][]*websocket.Conn),
	}
}

func (h *ChatHandler) GetHistory(c *gin.Context) {
	jobID := c.Param("jobId")
	history, err := h.service.GetChatHistory(c.Request.Context(), jobID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch chat history"})
		return
	}
	c.JSON(http.StatusOK, history)
}

func (h *ChatHandler) SendSystemMessage(c *gin.Context) {
	var req struct {
		JobID   string `json:"job_id" binding:"required"`
		Content string `json:"content" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	msg, err := h.service.SendMessage(c.Request.Context(), req.JobID, "SYSTEM", req.Content)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send system message"})
		return
	}

	h.broadcast(req.JobID, msg)
	c.JSON(http.StatusOK, msg)
}

func (h *ChatHandler) HandleWebSocket(c *gin.Context) {
	jobID := c.Query("jobId")
	if jobID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "jobId query parameter is required"})
		return
	}

	// Primary: read userID injected by the API Gateway via X-User-Id header
	userID := middleware.GetUserID(c)

	// Fallback: browser WebSocket connections cannot set custom headers,
	// so validate the JWT from the ?token= query parameter directly.
	if userID == "" {
		tokenStr := c.Query("token")
		if tokenStr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized: missing token"})
			return
		}

		jwtSecret := os.Getenv("JWT_SECRET")
		if jwtSecret == "" {
			jwtSecret = "super_secret_jwt_key_for_development"
		}

		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return []byte(jwtSecret), nil
		})
		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized: invalid token"})
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			if sub, ok := claims["sub"].(string); ok {
				userID = sub
			}
		}
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized: invalid token claims"})
			return
		}
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade to websocket: %v", err)
		return
	}

	h.addClient(jobID, conn)
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

func (h *ChatHandler) addClient(jobID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[jobID] = append(h.clients[jobID], conn)
}

func (h *ChatHandler) removeClient(jobID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	clients := h.clients[jobID]
	for i, c := range clients {
		if c == conn {
			h.clients[jobID] = append(clients[:i], clients[i+1:]...)
			break
		}
	}
	conn.Close()
}

func (h *ChatHandler) broadcast(jobID string, msg *domain.Message) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, conn := range h.clients[jobID] {
		err := conn.WriteJSON(msg)
		if err != nil {
			log.Printf("WS Write error: %v", err)
			// Connection will be removed by defer in HandleWebSocket
		}
	}
}
