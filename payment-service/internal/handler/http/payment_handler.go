package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/payment-service/internal/domain"
)

type PaymentHandler struct {
	service domain.PaymentService
}

func NewPaymentHandler(service domain.PaymentService) *PaymentHandler {
	return &PaymentHandler{service: service}
}

func (h *PaymentHandler) InitEscrow(c *gin.Context) {
	var req struct {
		JobID  string  `json:"job_id" binding:"required"`
		Amount float64 `json:"amount" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	clientSecret, intentID, err := h.service.InitializeEscrow(c.Request.Context(), req.JobID, req.Amount)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"client_secret": clientSecret,
		"intent_id":     intentID,
	})
}

func (h *PaymentHandler) ReleaseEscrow(c *gin.Context) {
	var req struct {
		JobID string `json:"job_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.ReleaseEscrow(c.Request.Context(), req.JobID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Funds released successfully"})
}

func (h *PaymentHandler) RefundEscrow(c *gin.Context) {
	var req struct {
		JobID string `json:"job_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.RefundEscrow(c.Request.Context(), req.JobID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Funds refunded successfully"})
}
