package service

import (
	"time"

	"ops-platform/internal/model"
	"ops-platform/internal/repository"
)

type ProjectService struct {
	projectRepo *repository.ProjectRepository
}

func NewProjectService(projectRepo *repository.ProjectRepository) *ProjectService {
	return &ProjectService{projectRepo: projectRepo}
}

func (s *ProjectService) Create(project *model.Project, memberIDs []int64) error {
	if project.Status == "" {
		project.Status = "active"
	}
	code, err := s.projectRepo.NextCode()
	if err != nil {
		return err
	}
	project.Code = code

	if err := s.projectRepo.Create(project); err != nil {
		return err
	}

	if len(memberIDs) > 0 {
		_ = s.projectRepo.SetMembers(project.ID, memberIDs)
	}
	return nil
}

func (s *ProjectService) GetByID(id int64) (*model.Project, error) {
	return s.projectRepo.FindByID(id)
}

func (s *ProjectService) List() ([]model.Project, error) {
	return s.projectRepo.List()
}

func (s *ProjectService) Update(project *model.Project, memberIDs []int64) error {
	// Auto-set status to "review" when actual_end_date <= today and status is active
	if project.ActualEndDate != nil && project.Status == "active" {
		today := time.Now().Format("2006-01-02")
		actualDate := project.ActualEndDate.Format("2006-01-02")
		if actualDate <= today {
			project.Status = "review"
		}
	}

	if err := s.projectRepo.Update(project); err != nil {
		return err
	}
	if memberIDs != nil {
		_ = s.projectRepo.SetMembers(project.ID, memberIDs)
	}
	return nil
}

func (s *ProjectService) Delete(id int64) error {
	return s.projectRepo.Delete(id)
}

func (s *ProjectService) GetMemberIDs(projectID int64) ([]int64, error) {
	return s.projectRepo.GetMemberIDs(projectID)
}

// Review handles project completion review
func (s *ProjectService) Review(projectID int64, approved bool) error {
	if approved {
		return s.projectRepo.UpdateStatus(projectID, "completed")
	}
	return nil
}

// SubmitRectification records a rectification submission and sets status to rectifying
func (s *ProjectService) SubmitRectification(projectID, operatorID int64, content string) error {
	rec := &model.ProjectRectification{
		ProjectID:  projectID,
		Type:       "rectification",
		Content:    content,
		OperatorID: operatorID,
	}
	if err := s.projectRepo.AddRectification(rec); err != nil {
		return err
	}
	return s.projectRepo.UpdateStatus(projectID, "rectifying")
}

// RejectRectification records a rejection and keeps status as rectifying
func (s *ProjectService) RejectRectification(projectID, operatorID int64, content string) error {
	rec := &model.ProjectRectification{
		ProjectID:  projectID,
		Type:       "rejection",
		Content:    content,
		OperatorID: operatorID,
	}
	if err := s.projectRepo.AddRectification(rec); err != nil {
		return err
	}
	return s.projectRepo.UpdateStatus(projectID, "rectifying")
}

// RectifyApprove approves rectification and sets status to completed
func (s *ProjectService) RectifyApprove(projectID int64) error {
	return s.projectRepo.UpdateStatus(projectID, "completed")
}

// GetRectifications returns rectification history for a project
func (s *ProjectService) GetRectifications(projectID int64) ([]model.ProjectRectification, error) {
	return s.projectRepo.GetRectifications(projectID)
}
