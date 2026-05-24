package service

import (
	"ops-platform/internal/model"
	"ops-platform/internal/repository"
)

type AssetService struct {
	assetRepo *repository.AssetRepository
}

func NewAssetService(assetRepo *repository.AssetRepository) *AssetService {
	return &AssetService{assetRepo: assetRepo}
}

func (s *AssetService) Create(a *model.Asset) error {
	if a.Status == "" {
		a.Status = "active"
	}
	return s.assetRepo.Create(a)
}

func (s *AssetService) Update(a *model.Asset) error {
	return s.assetRepo.Update(a)
}

func (s *AssetService) GetByID(id int64) (*model.Asset, error) {
	return s.assetRepo.FindByID(id)
}

func (s *AssetService) List(assetType, status, keyword string) ([]model.Asset, error) {
	return s.assetRepo.List(assetType, status, keyword)
}

func (s *AssetService) Delete(id int64) error {
	return s.assetRepo.Delete(id)
}
