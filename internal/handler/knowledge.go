package handler

import (
	"encoding/json"
	"strconv"

	"ops-platform/internal/model"
	"ops-platform/internal/pkg/response"
	"ops-platform/internal/service"

	"github.com/gin-gonic/gin"
)

type KnowledgeHandler struct {
	kbService *service.KnowledgeService
}

func NewKnowledgeHandler(kbService *service.KnowledgeService) *KnowledgeHandler {
	return &KnowledgeHandler{kbService: kbService}
}

// Categories
func (h *KnowledgeHandler) ListCategories(c *gin.Context) {
	cats, err := h.kbService.ListCategories()
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, cats)
}

// Articles
func (h *KnowledgeHandler) CreateArticle(c *gin.Context) {
	var req struct {
		Title       string   `json:"title" binding:"required"`
		Content     string   `json:"content"`
		ContentHTML string   `json:"content_html"`
		CategoryID  int64    `json:"category_id"`
		Status      string   `json:"status"`
		Tags        []string `json:"tags"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Title is required")
		return
	}

	authorID := c.GetInt64("user_id")
	tagsJSON := []byte("[]")
	if req.Tags != nil {
		tagsJSON = marshalJSON(req.Tags)
	}

	article := &model.KBArticle{
		Title:       req.Title,
		Content:     req.Content,
		ContentHTML: req.ContentHTML,
		CategoryID:  req.CategoryID,
		Status:      req.Status,
		AuthorID:    authorID,
		Tags:        tagsJSON,
	}

	if article.Status == "" {
		article.Status = "draft"
	}

	if err := h.kbService.CreateArticle(article); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, article)
}

func (h *KnowledgeHandler) GetArticle(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}
	article, err := h.kbService.GetArticle(id)
	if err != nil {
		response.NotFound(c, "Article not found")
		return
	}
	files, _ := h.kbService.GetFiles(id)
	if files == nil {
		files = []model.KBFile{}
	}
	response.Success(c, gin.H{"article": article, "files": files})
}

func (h *KnowledgeHandler) ListArticles(c *gin.Context) {
	categoryID, _ := strconv.ParseInt(c.Query("category_id"), 10, 64)
	keyword := c.Query("keyword")

	articles, err := h.kbService.ListArticles(categoryID, keyword)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, articles)
}

func (h *KnowledgeHandler) UpdateArticle(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}

	var req struct {
		Title       string   `json:"title" binding:"required"`
		Content     string   `json:"content"`
		ContentHTML string   `json:"content_html"`
		CategoryID  int64    `json:"category_id"`
		Status      string   `json:"status"`
		Tags        []string `json:"tags"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Title is required")
		return
	}

	tagsJSON := []byte("[]")
	if req.Tags != nil {
		tagsJSON = marshalJSON(req.Tags)
	}

	article := &model.KBArticle{
		ID:          id,
		Title:       req.Title,
		Content:     req.Content,
		ContentHTML: req.ContentHTML,
		CategoryID:  req.CategoryID,
		Status:      req.Status,
		Tags:        tagsJSON,
	}

	if err := h.kbService.UpdateArticle(article); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func (h *KnowledgeHandler) DeleteArticle(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}
	if err := h.kbService.DeleteArticle(id); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

// Files
func (h *KnowledgeHandler) UploadFile(c *gin.Context) {
	articleID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid article ID")
		return
	}

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		response.BadRequest(c, "Please select a file")
		return
	}
	defer file.Close()

	uploaderID := c.GetInt64("user_id")
	f, err := h.kbService.UploadFile(articleID, uploaderID, header.Filename, file)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, f)
}

func (h *KnowledgeHandler) ListFiles(c *gin.Context) {
	articleID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid article ID")
		return
	}
	files, err := h.kbService.GetFiles(articleID)
	if err != nil {
		response.Success(c, []interface{}{})
		return
	}
	if files == nil {
		files = []model.KBFile{}
	}
	response.Success(c, files)
}

func (h *KnowledgeHandler) DownloadFile(c *gin.Context) {
	fileID, err := strconv.ParseInt(c.Param("file_id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid file ID")
		return
	}
	f, err := h.kbService.GetFile(fileID)
	if err != nil {
		response.NotFound(c, "File not found")
		return
	}
	c.Header("Content-Disposition", "attachment; filename="+f.Filename)
	c.File(f.Filepath)
}

func (h *KnowledgeHandler) DeleteFile(c *gin.Context) {
	fileID, err := strconv.ParseInt(c.Param("file_id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "Invalid file ID")
		return
	}
	if err := h.kbService.DeleteFile(fileID); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Success(c, nil)
}

func marshalJSON(v interface{}) []byte {
	b, _ := json.Marshal(v)
	return b
}
