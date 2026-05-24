package model

import "time"

type Asset struct {
	ID             int64      `json:"id" db:"id"`
	Name           string     `json:"name" db:"name"`
	Type           string     `json:"type" db:"type"`
	IP             string     `json:"ip" db:"ip"`
	Status         string     `json:"status" db:"status"`
	Location       string     `json:"location" db:"location"`
	SerialNumber   string     `json:"serial_number" db:"serial_number"`
	Brand          string     `json:"brand" db:"brand"`
	Model          string     `json:"model" db:"model"`
	PurchaseDate   *time.Time `json:"purchase_date" db:"purchase_date"`
	WarrantyDate   *time.Time `json:"warranty_date" db:"warranty_date"`
	ResponsibleID  *int64     `json:"responsible_id" db:"responsible_id"`
	Description    string     `json:"description" db:"description"`
	Metadata       []byte     `json:"metadata" db:"metadata"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}
