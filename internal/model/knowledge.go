package model

import "time"

type KBCategory struct {
	ID        int64     `json:"id" db:"id"`
	Name      string    `json:"name" db:"name"`
	ParentID  int64     `json:"parent_id" db:"parent_id"`
	SortOrder int       `json:"sort_order" db:"sort_order"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type KBArticle struct {
	ID          int64     `json:"id" db:"id"`
	Title       string    `json:"title" db:"title"`
	Content     string    `json:"content" db:"content"`
	ContentHTML string    `json:"content_html" db:"content_html"`
	CategoryID  int64     `json:"category_id" db:"category_id"`
	Status      string    `json:"status" db:"status"`
	AuthorID    int64     `json:"author_id" db:"author_id"`
	Tags        []byte    `json:"tags" db:"tags"`
	ViewCount   int       `json:"view_count" db:"view_count"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type KBFile struct {
	ID         int64     `json:"id" db:"id"`
	ArticleID  int64     `json:"article_id" db:"article_id"`
	Filename   string    `json:"filename" db:"filename"`
	Filepath   string    `json:"filepath" db:"filepath"`
	Filesize   int64     `json:"filesize" db:"filesize"`
	Filetype   string    `json:"filetype" db:"filetype"`
	UploaderID int64     `json:"uploader_id" db:"uploader_id"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}
