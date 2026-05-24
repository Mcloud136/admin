package router

import (
	"ops-platform/internal/handler"
	"ops-platform/internal/middleware"
	"ops-platform/internal/model"

	"github.com/gin-gonic/gin"
)

func Setup(
	userHandler *handler.UserHandler,
	teamHandler *handler.TeamHandler,
	ticketHandler *handler.TicketHandler,
	projectHandler *handler.ProjectHandler,
	completionHandler *handler.CompletionHandler,
	knowledgeHandler *handler.KnowledgeHandler,
	assetHandler *handler.AssetHandler,
) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.Logger())
	r.Use(middleware.CORSMiddleware())

	api := r.Group("/api")
	{
		// Public routes
		api.POST("/login", userHandler.Login)

		// Authenticated routes
		auth := api.Group("")
		auth.Use(middleware.JWTAuth())
		{
			// Profile
			auth.GET("/profile", userHandler.GetProfile)

			// Users: all can list/get, admin+supervisor for update, admin-only for create/delete/reset-password
			users := auth.Group("/users")
			{
				users.GET("", userHandler.List)
				users.GET("/:id", userHandler.GetByID)
				users.PUT("/:id", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), userHandler.Update)
			}
			usersAdmin := auth.Group("/users")
			usersAdmin.Use(middleware.RBAC(model.RoleAdmin))
			{
				usersAdmin.POST("", userHandler.Create)
				usersAdmin.DELETE("/:id", userHandler.Delete)
				usersAdmin.POST("/:id/reset-password", userHandler.ResetPassword)
			}

			// Teams: all can list/get, admin+supervisor for CRUD
			teams := auth.Group("/teams")
			{
				teams.GET("", teamHandler.List)
				teams.GET("/:id", teamHandler.GetByID)
			}
			teamsAdmin := auth.Group("/teams")
			teamsAdmin.Use(middleware.RBAC(model.RoleAdmin, model.RoleSupervisor))
			{
				teamsAdmin.POST("", teamHandler.Create)
				teamsAdmin.PUT("/:id", teamHandler.Update)
				teamsAdmin.DELETE("/:id", teamHandler.Delete)
			}

			// Projects: all can list/get, admin+supervisor for create/update/delete
			projects := auth.Group("/projects")
			{
				projects.GET("", projectHandler.List)
				projects.GET("/:id", projectHandler.GetByID)
			}
			projectsMgmt := auth.Group("/projects")
			projectsMgmt.Use(middleware.RBAC(model.RoleAdmin, model.RoleSupervisor))
			{
				projectsMgmt.POST("", projectHandler.Create)
				projectsMgmt.PUT("/:id", projectHandler.Update)
				projectsMgmt.DELETE("/:id", projectHandler.Delete)
				projectsMgmt.POST("/:id/review", projectHandler.Review)
				projectsMgmt.POST("/:id/rectification", projectHandler.SubmitRectification)
				projectsMgmt.POST("/:id/rectification/reject", projectHandler.RejectRectification)
				projectsMgmt.POST("/:id/rectification/approve", projectHandler.RectifyApprove)
				projectsMgmt.GET("/:id/rectifications", projectHandler.GetRectifications)
			}

			// Tickets
			tickets := auth.Group("/tickets")
			{
				tickets.POST("", ticketHandler.Create)
				tickets.GET("", ticketHandler.List)
				tickets.GET("/:id", ticketHandler.GetByID)
				tickets.PUT("/:id", ticketHandler.Update)
				tickets.POST("/:id/assign", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), ticketHandler.Assign)
				tickets.POST("/:id/transfer", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), ticketHandler.Transfer)
				tickets.POST("/:id/suspend", ticketHandler.Suspend)
				tickets.POST("/:id/resume", ticketHandler.Resume)
				tickets.POST("/:id/progress", ticketHandler.AddProgress)
				tickets.POST("/:id/logs", ticketHandler.AddLog)
				tickets.GET("/:id/logs", ticketHandler.GetLogs)
				tickets.POST("/:id/complete", ticketHandler.Complete)
				tickets.POST("/:id/review", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), ticketHandler.Review)
				tickets.POST("/:id/archive", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), ticketHandler.Archive)
				tickets.DELETE("/:id", middleware.RBAC(model.RoleAdmin), ticketHandler.Delete)
			}

			// Completion reports & file uploads
			completions := auth.Group("/tickets")
			{
				completions.POST("/:id/completion", completionHandler.Submit)
				completions.GET("/:id/completion", completionHandler.Get)
				completions.POST("/:id/files", completionHandler.UploadFile)
				completions.GET("/:id/files", completionHandler.ListFiles)
				completions.GET("/:id/files/:file_id/download", completionHandler.DownloadFile)
				completions.DELETE("/:id/files/:file_id", completionHandler.DeleteFile)
			}

			// Knowledge base
			kb := auth.Group("/knowledge")
			{
				kb.GET("/categories", knowledgeHandler.ListCategories)
				kb.GET("/articles", knowledgeHandler.ListArticles)
				kb.GET("/articles/:id", knowledgeHandler.GetArticle)
				kb.POST("/articles", knowledgeHandler.CreateArticle)
				kb.PUT("/articles/:id", knowledgeHandler.UpdateArticle)
				kb.DELETE("/articles/:id", knowledgeHandler.DeleteArticle)
				kb.POST("/articles/:id/files", knowledgeHandler.UploadFile)
				kb.GET("/articles/:id/files", knowledgeHandler.ListFiles)
				kb.GET("/articles/:id/files/:file_id/download", knowledgeHandler.DownloadFile)
				kb.DELETE("/articles/:id/files/:file_id", knowledgeHandler.DeleteFile)
			}

			// Assets
			assets := auth.Group("/assets")
			{
				assets.GET("", assetHandler.List)
				assets.GET("/:id", assetHandler.GetByID)
				assets.POST("", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), assetHandler.Create)
				assets.PUT("/:id", middleware.RBAC(model.RoleAdmin, model.RoleSupervisor), assetHandler.Update)
				assets.DELETE("/:id", middleware.RBAC(model.RoleAdmin), assetHandler.Delete)
			}
		}
	}

	return r
}
