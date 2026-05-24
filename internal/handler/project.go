package handler

import (
	"strconv"
	"time"

	"ops-platform/internal/model"
	"ops-platform/internal/pkg/response"
	"ops-platform/internal/service"

	"github.com/gin-gonic/gin"
)

type ProjectHandler struct {
	projectService *service.ProjectService
}

func NewProjectHandler(projectService *service.ProjectService) *ProjectHandler {
	return &ProjectHandler{projectService: projectService}
}

func parseDatePtr(s *string) *time.Time {
	if s == nil || *s == "" {
		return nil
	}
	t, err := time.Parse("2006-01-02", *s)
	if err != nil {
		t, err = time.Parse(time.RFC3339, *s)
		if err != nil {
			return nil
		}
	}
	return &t
}

func (h *ProjectHandler) Create(c *gin.Context) {
	var req model.CreateProjectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "请求参数错误")
		return
	}

	project := &model.Project{
		Name:          req.Name,
		Description:   req.Description,
		Type:          req.Type,
		Priority:      req.Priority,
		Status:        "active",
		Requester:     req.Requester,
		ManagerID:     req.ManagerID,
		Budget:        req.Budget,
		Remark:        req.Remark,
		StartDate:     parseDatePtr(req.StartDate),
		EndDate:       parseDatePtr(req.EndDate),
		ActualEndDate: parseDatePtr(req.ActualEndDate),
	}

	if err := h.projectService.Create(project, req.MemberIDs); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, project)
}

func (h *ProjectHandler) List(c *gin.Context) {
	projects, err := h.projectService.List()
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, projects)
}

func (h *ProjectHandler) GetByID(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}
	project, err := h.projectService.GetByID(id)
	if err != nil {
		response.NotFound(c, "项目不存在")
		return
	}
	memberIDs, _ := h.projectService.GetMemberIDs(id)
	rectifications, _ := h.projectService.GetRectifications(id)
	if rectifications == nil {
		rectifications = []model.ProjectRectification{}
	}
	result := gin.H{
		"project":         project,
		"member_ids":      memberIDs,
		"rectifications":  rectifications,
	}
	response.Success(c, result)
}

func (h *ProjectHandler) Update(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}

	var req model.CreateProjectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "请求参数错误")
		return
	}

	project := &model.Project{
		ID:            id,
		Name:          req.Name,
		Description:   req.Description,
		Type:          req.Type,
		Priority:      req.Priority,
		Status:        req.Status,
		Requester:     req.Requester,
		ManagerID:     req.ManagerID,
		Budget:        req.Budget,
		Remark:        req.Remark,
		StartDate:     parseDatePtr(req.StartDate),
		EndDate:       parseDatePtr(req.EndDate),
		ActualEndDate: parseDatePtr(req.ActualEndDate),
	}

	if err := h.projectService.Update(project, req.MemberIDs); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *ProjectHandler) Delete(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}
	if err := h.projectService.Delete(id); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *ProjectHandler) Review(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}

	var req struct {
		Approved bool `json:"approved"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "请求参数错误")
		return
	}

	if err := h.projectService.Review(id, req.Approved); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *ProjectHandler) SubmitRectification(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}

	var req struct {
		Content string `json:"content" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "请填写整改内容")
		return
	}

	operatorID := c.GetInt64("user_id")
	if err := h.projectService.SubmitRectification(id, operatorID, req.Content); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *ProjectHandler) RejectRectification(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}

	var req struct {
		Content string `json:"content" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "请填写驳回意见")
		return
	}

	operatorID := c.GetInt64("user_id")
	if err := h.projectService.RejectRectification(id, operatorID, req.Content); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *ProjectHandler) RectifyApprove(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}

	if err := h.projectService.RectifyApprove(id); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *ProjectHandler) GetRectifications(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "无效的ID")
		return
	}

	recs, err := h.projectService.GetRectifications(id)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	if recs == nil {
		recs = []model.ProjectRectification{}
	}
	response.Success(c, recs)
}
