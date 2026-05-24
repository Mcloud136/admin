package repository

import (
	"ops-platform/internal/model"

	"github.com/jmoiron/sqlx"
)

type KnowledgeRepository struct {
	db *sqlx.DB
}

func NewKnowledgeRepository(db *sqlx.DB) *KnowledgeRepository {
	return &KnowledgeRepository{db: db}
}

// Categories
func (r *KnowledgeRepository) ListCategories() ([]model.KBCategory, error) {
	var cats []model.KBCategory
	err := r.db.Select(&cats, "SELECT * FROM kb_categories ORDER BY sort_order")
	return cats, err
}

// Articles
func (r *KnowledgeRepository) CreateArticle(a *model.KBArticle) error {
	if a.Tags == nil {
		a.Tags = []byte("[]")
	}
	query := `INSERT INTO kb_articles (title, content, content_html, category_id, status, author_id, tags)
		VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, created_at, updated_at`
	return r.db.QueryRow(query, a.Title, a.Content, a.ContentHTML, a.CategoryID,
		a.Status, a.AuthorID, a.Tags).Scan(&a.ID, &a.CreatedAt, &a.UpdatedAt)
}

func (r *KnowledgeRepository) UpdateArticle(a *model.KBArticle) error {
	if a.Tags == nil {
		a.Tags = []byte("[]")
	}
	query := `UPDATE kb_articles SET title=$1, content=$2, content_html=$3, category_id=$4,
		status=$5, tags=$6, updated_at=NOW() WHERE id=$7`
	_, err := r.db.Exec(query, a.Title, a.Content, a.ContentHTML, a.CategoryID,
		a.Status, a.Tags, a.ID)
	return err
}

func (r *KnowledgeRepository) FindArticleByID(id int64) (*model.KBArticle, error) {
	var a model.KBArticle
	err := r.db.Get(&a, "SELECT * FROM kb_articles WHERE id = $1", id)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (r *KnowledgeRepository) ListArticles(categoryID int64, keyword string) ([]model.KBArticle, error) {
	var articles []model.KBArticle
	var err error
	if categoryID > 0 && keyword != "" {
		err = r.db.Select(&articles, "SELECT * FROM kb_articles WHERE category_id=$1 AND title ILIKE '%'||$2||'%' ORDER BY updated_at DESC", categoryID, keyword)
	} else if categoryID > 0 {
		err = r.db.Select(&articles, "SELECT * FROM kb_articles WHERE category_id=$1 ORDER BY updated_at DESC", categoryID)
	} else if keyword != "" {
		err = r.db.Select(&articles, "SELECT * FROM kb_articles WHERE title ILIKE '%'||$1||'%' ORDER BY updated_at DESC", keyword)
	} else {
		err = r.db.Select(&articles, "SELECT * FROM kb_articles ORDER BY updated_at DESC")
	}
	return articles, err
}

func (r *KnowledgeRepository) DeleteArticle(id int64) error {
	_, err := r.db.Exec("DELETE FROM kb_articles WHERE id = $1", id)
	return err
}

func (r *KnowledgeRepository) IncrementViewCount(id int64) error {
	_, err := r.db.Exec("UPDATE kb_articles SET view_count = view_count + 1 WHERE id = $1", id)
	return err
}

// Files
func (r *KnowledgeRepository) CreateFile(f *model.KBFile) error {
	query := `INSERT INTO kb_files (article_id, filename, filepath, filesize, filetype, uploader_id)
		VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, created_at`
	return r.db.QueryRow(query, f.ArticleID, f.Filename, f.Filepath, f.Filesize, f.Filetype, f.UploaderID).
		Scan(&f.ID, &f.CreatedAt)
}

func (r *KnowledgeRepository) FindFilesByArticleID(articleID int64) ([]model.KBFile, error) {
	var files []model.KBFile
	err := r.db.Select(&files, "SELECT * FROM kb_files WHERE article_id = $1 ORDER BY created_at", articleID)
	return files, err
}

func (r *KnowledgeRepository) FindFileByID(id int64) (*model.KBFile, error) {
	var f model.KBFile
	err := r.db.Get(&f, "SELECT * FROM kb_files WHERE id = $1", id)
	if err != nil {
		return nil, err
	}
	return &f, nil
}

func (r *KnowledgeRepository) DeleteFile(id int64) error {
	_, err := r.db.Exec("DELETE FROM kb_files WHERE id = $1", id)
	return err
}
