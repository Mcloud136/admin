package service

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"ops-platform/internal/model"
	"ops-platform/internal/repository"
)

type KnowledgeService struct {
	kbRepo *repository.KnowledgeRepository
}

func NewKnowledgeService(kbRepo *repository.KnowledgeRepository) *KnowledgeService {
	return &KnowledgeService{kbRepo: kbRepo}
}

// Categories
func (s *KnowledgeService) ListCategories() ([]model.KBCategory, error) {
	return s.kbRepo.ListCategories()
}

// Articles
func (s *KnowledgeService) CreateArticle(a *model.KBArticle) error {
	return s.kbRepo.CreateArticle(a)
}

func (s *KnowledgeService) UpdateArticle(a *model.KBArticle) error {
	return s.kbRepo.UpdateArticle(a)
}

func (s *KnowledgeService) GetArticle(id int64) (*model.KBArticle, error) {
	a, err := s.kbRepo.FindArticleByID(id)
	if err != nil {
		return nil, err
	}
	_ = s.kbRepo.IncrementViewCount(id)
	return a, nil
}

func (s *KnowledgeService) ListArticles(categoryID int64, keyword string) ([]model.KBArticle, error) {
	return s.kbRepo.ListArticles(categoryID, keyword)
}

func (s *KnowledgeService) DeleteArticle(id int64) error {
	return s.kbRepo.DeleteArticle(id)
}

// Files
func (s *KnowledgeService) UploadFile(articleID, uploaderID int64, filename string, reader io.Reader) (*model.KBFile, error) {
	cleanName := filepath.Base(filename)
	ext := strings.ToLower(filepath.Ext(cleanName))

	uploadDir := "uploads/kb"
	os.MkdirAll(uploadDir, 0755)

	storedName := fmt.Sprintf("%d_%d%s", articleID, time.Now().UnixNano(), ext)
	savePath := filepath.Join(uploadDir, storedName)

	dst, err := os.Create(savePath)
	if err != nil {
		return nil, err
	}
	defer dst.Close()

	size, err := io.Copy(dst, reader)
	if err != nil {
		os.Remove(savePath)
		return nil, err
	}

	f := &model.KBFile{
		ArticleID:  articleID,
		Filename:   cleanName,
		Filepath:   savePath,
		Filesize:   size,
		Filetype:   ext,
		UploaderID: uploaderID,
	}
	if err := s.kbRepo.CreateFile(f); err != nil {
		os.Remove(savePath)
		return nil, err
	}
	return f, nil
}

func (s *KnowledgeService) GetFiles(articleID int64) ([]model.KBFile, error) {
	return s.kbRepo.FindFilesByArticleID(articleID)
}

func (s *KnowledgeService) GetFile(fileID int64) (*model.KBFile, error) {
	return s.kbRepo.FindFileByID(fileID)
}

func (s *KnowledgeService) DeleteFile(fileID int64) error {
	f, err := s.kbRepo.FindFileByID(fileID)
	if err != nil {
		return err
	}
	os.Remove(f.Filepath)
	return s.kbRepo.DeleteFile(fileID)
}
