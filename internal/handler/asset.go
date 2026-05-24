package handler

import (
	"strconv"

	"ops-platform/internal/model"
	"ops-platform/internal/pkg/response"
	"ops-platform/internal/service"

	"github.com/gin-gonic/gin"
)

type AssetHandler struct {
	assetService *service.AssetService
}

func NewAssetHandler(assetService *service.AssetService) *AssetHandler {
	return &AssetHandler{assetService: assetService}
}

func (h *AssetHandler) Create(c *gin.Context) {
	var asset model.Asset
	if err := c.ShouldBindJSON(&asset); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}
	if err := h.assetService.Create(&asset); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, asset)
}

func (h *AssetHandler) GetByID(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}
	asset, err := h.assetService.GetByID(id)
	if err != nil {
		response.NotFound(c, "Asset not found")
		return
	}
	response.Success(c, asset)
}

func (h *AssetHandler) List(c *gin.Context) {
	assetType := c.Query("type")
	status := c.Query("status")
	keyword := c.Query("keyword")

	assets, err := h.assetService.List(assetType, status, keyword)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, assets)
}

func (h *AssetHandler) Update(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}
	var asset model.Asset
	if err := c.ShouldBindJSON(&asset); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}
	asset.ID = id
	if err := h.assetService.Update(&asset); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *AssetHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}
	if err := h.assetService.Delete(id); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}
