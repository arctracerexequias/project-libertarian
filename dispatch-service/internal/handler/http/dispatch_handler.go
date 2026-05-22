package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/dispatch-service/internal/domain"
)

type DispatchHandler struct {
	service domain.DispatchService
}

func NewDispatchHandler(service domain.DispatchService) *DispatchHandler {
	return &DispatchHandler{service: service}
}

func (h *DispatchHandler) UpdateLocation(c *gin.Context) {
	var req struct {
		ProviderID string  `json:"provider_id" binding:"required"`
		Lat        float64 `json:"lat" binding:"required"`
		Lng        float64 `json:"lng" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.UpdateProviderLocation(c.Request.Context(), req.ProviderID, req.Lat, req.Lng); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Location updated"})
}

func (h *DispatchHandler) Dispatch(c *gin.Context) {
	var req domain.DispatchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	locations, err := h.service.DispatchJob(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"locations": locations})
}
