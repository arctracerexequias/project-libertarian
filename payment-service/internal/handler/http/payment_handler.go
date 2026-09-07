package http

import (
	"errors"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/service-marketplace/payment-service/internal/domain"
	"github.com/service-marketplace/shared-contracts/pkg/middleware"
	"net/http"
)

type PaymentHandler struct{ service domain.PaymentService }

func NewPaymentHandler(service domain.PaymentService) *PaymentHandler {
	return &PaymentHandler{service: service}
}
func paymentError(c *gin.Context, err error) {
	code := http.StatusBadGateway
	if errors.Is(err, domain.ErrForbidden) {
		code = 403
	} else if errors.Is(err, domain.ErrState) {
		code = 409
	}
	c.JSON(code, gin.H{"error": err.Error()})
}
func jobRequest(c *gin.Context) (string, bool) {
	var req struct {
		JobID string `json:"job_id" binding:"required,uuid"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": "valid job_id required"})
		return "", false
	}
	return req.JobID, true
}
func (h *PaymentHandler) InitEscrow(c *gin.Context) {
	id, ok := jobRequest(c)
	if !ok {
		return
	}
	tx, err := h.service.InitializeEscrow(c.Request.Context(), id, middleware.GetUserID(c))
	if err != nil {
		paymentError(c, err)
		return
	}
	c.JSON(200, tx)
}
func (h *PaymentHandler) GetEscrow(c *gin.Context) {
	id := c.Param("jobId")
	if _, err := uuid.Parse(id); err != nil {
		c.JSON(400, gin.H{"error": "valid job_id required"})
		return
	}
	tx, err := h.service.GetEscrow(c.Request.Context(), id, middleware.GetUserID(c))
	if err != nil {
		paymentError(c, err)
		return
	}
	c.JSON(200, tx)
}
func (h *PaymentHandler) ReleaseEscrow(c *gin.Context) {
	id, ok := jobRequest(c)
	if !ok {
		return
	}
	if err := h.service.ReleaseEscrow(c.Request.Context(), id, middleware.GetUserID(c)); err != nil {
		paymentError(c, err)
		return
	}
	c.JSON(200, gin.H{"message": "Payment captured"})
}
func (h *PaymentHandler) RefundEscrow(c *gin.Context) {
	id, ok := jobRequest(c)
	if !ok {
		return
	}
	if err := h.service.RefundEscrow(c.Request.Context(), id, middleware.GetUserID(c)); err != nil {
		paymentError(c, err)
		return
	}
	c.JSON(200, gin.H{"message": "Payment refunded or authorization cancelled"})
}
