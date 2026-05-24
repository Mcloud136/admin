package repository

import (
	"fmt"
	"strings"

	"ops-platform/internal/model"

	"github.com/jmoiron/sqlx"
)

type AssetRepository struct {
	db *sqlx.DB
}

func NewAssetRepository(db *sqlx.DB) *AssetRepository {
	return &AssetRepository{db: db}
}

func (r *AssetRepository) Create(a *model.Asset) error {
	if a.Metadata == nil {
		a.Metadata = []byte("{}")
	}
	query := `INSERT INTO assets (name, type, ip, status, location, serial_number, brand, model,
		purchase_date, warranty_date, responsible_id, description, metadata)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id, created_at, updated_at`
	return r.db.QueryRow(query,
		a.Name, a.Type, a.IP, a.Status, a.Location, a.SerialNumber, a.Brand, a.Model,
		a.PurchaseDate, a.WarrantyDate, a.ResponsibleID, a.Description, a.Metadata,
	).Scan(&a.ID, &a.CreatedAt, &a.UpdatedAt)
}

func (r *AssetRepository) Update(a *model.Asset) error {
	if a.Metadata == nil {
		a.Metadata = []byte("{}")
	}
	query := `UPDATE assets SET name=$1, type=$2, ip=$3, status=$4, location=$5, serial_number=$6,
		brand=$7, model=$8, purchase_date=$9, warranty_date=$10, responsible_id=$11, description=$12,
		metadata=$13, updated_at=NOW() WHERE id=$14`
	_, err := r.db.Exec(query,
		a.Name, a.Type, a.IP, a.Status, a.Location, a.SerialNumber, a.Brand, a.Model,
		a.PurchaseDate, a.WarrantyDate, a.ResponsibleID, a.Description, a.Metadata, a.ID)
	return err
}

func (r *AssetRepository) FindByID(id int64) (*model.Asset, error) {
	var a model.Asset
	err := r.db.Get(&a, "SELECT * FROM assets WHERE id = $1", id)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (r *AssetRepository) List(assetType, status, keyword string) ([]model.Asset, error) {
	where := []string{"1=1"}
	args := []interface{}{}
	idx := 1

	if assetType != "" {
		where = append(where, fmt.Sprintf("type = $%d", idx))
		args = append(args, assetType)
		idx++
	}
	if status != "" {
		where = append(where, fmt.Sprintf("status = $%d", idx))
		args = append(args, status)
		idx++
	}
	if keyword != "" {
		where = append(where, fmt.Sprintf("(name ILIKE '%%' || $%d || '%%' OR ip ILIKE '%%' || $%d || '%%' OR serial_number ILIKE '%%' || $%d || '%%')", idx, idx, idx))
		args = append(args, keyword)
		idx++
	}

	query := fmt.Sprintf("SELECT * FROM assets WHERE %s ORDER BY id DESC", strings.Join(where, " AND "))
	var assets []model.Asset
	err := r.db.Select(&assets, query, args...)
	return assets, err
}

func (r *AssetRepository) Delete(id int64) error {
	_, err := r.db.Exec("UPDATE tickets SET asset_id = NULL WHERE asset_id = $1", id)
	if err != nil {
		return err
	}
	_, err = r.db.Exec("DELETE FROM assets WHERE id = $1", id)
	return err
}
