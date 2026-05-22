package http

import (
	"net/http"

	"strconv"
	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/marketplace-service/internal/domain"
	"github.com/service-marketplace/shared-contracts/pkg/middleware"
)

type MarketplaceHandler struct {
	service domain.MarketplaceService
}

func NewMarketplaceHandler(service domain.MarketplaceService) *MarketplaceHandler {
	return &MarketplaceHandler{service: service}
}

func (h *MarketplaceHandler) GetJobs(c *gin.Context) {
	category := c.Query("category")
	lat, _ := strconv.ParseFloat(c.DefaultQuery("lat", "0"), 64)
	lng, _ := strconv.ParseFloat(c.DefaultQuery("lng", "0"), 64)
	radius, _ := strconv.ParseFloat(c.DefaultQuery("radius", "0"), 64)

	jobs, err := h.service.ListJobs(c.Request.Context(), category, lat, lng, radius)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch jobs"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"jobs": jobs})
}

func (h *MarketplaceHandler) PostJob(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req domain.CreateJobRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	jobID, err := h.service.PostJob(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create job"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": jobID})
}

func (h *MarketplaceHandler) PlaceBid(c *gin.Context) {
	userID := middleware.GetUserID(c)
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	jobID := c.Param("id")
	var req domain.CreateBidRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	bidID, err := h.service.PlaceBid(c.Request.Context(), userID, jobID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit bid"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": bidID})
}

func (h *MarketplaceHandler) GetBids(c *gin.Context) {
	jobID := c.Param("id")
	bids, err := h.service.ListBids(c.Request.Context(), jobID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch bids"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bids": bids})
}

func (h *MarketplaceHandler) AcceptBid(c *gin.Context) {
	jobID := c.Param("id")
	bidID := c.Param("bidId")
	err := h.service.AcceptOffer(c.Request.Context(), jobID, bidID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to accept bid"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Bid accepted"})
}

func (h *MarketplaceHandler) CompleteJob(c *gin.Context) {
	userID := middleware.GetUserID(c)
	jobID := c.Param("id")
	var req domain.CompleteJobRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.MarkComplete(c.Request.Context(), jobID, userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete job"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Job completed"})
}

func (h *MarketplaceHandler) GetProviderBids(c *gin.Context) {
	userID := middleware.GetUserID(c)
	bids, err := h.service.ListProviderBids(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch bids"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bids": bids})
}

func (h *MarketplaceHandler) GetProviderJobs(c *gin.Context) {
	userID := middleware.GetUserID(c)
	jobs, err := h.service.ListProviderJobs(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch jobs"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"jobs": jobs})
}

func (h *MarketplaceHandler) GetInsights(c *gin.Context) {
	category := c.Query("category")
	avg, count, err := h.service.GetInsights(c.Request.Context(), category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch insights"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"average": avg, "count": count})
}

func (h *MarketplaceHandler) UpdateJobStatus(c *gin.Context) {
	jobID := c.Param("id")
	var req struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.UpdateJobStatus(c.Request.Context(), jobID, req.Status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update job status"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Job status updated"})
}
