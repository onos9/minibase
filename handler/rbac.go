package handler

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/harranali/authority"
)

func SetupRoutes(app *fiber.App) {
	auth := authority.Resolve()

	app.Post("/roles", func(c *fiber.Ctx) error {
		var role authority.Role
		if err := c.BodyParser(&role); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Bad request"})
		}
		err := auth.CreateRole(role)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to create role"})
		}
		return c.JSON(fiber.Map{"message": "Role created successfully"})
	})

	app.Get("/roles/:slug", func(c *fiber.Ctx) error {
		roleSlug := c.Params("slug")
		role, err := auth.GetRolePermissions(roleSlug)
		if err != nil {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Role not found"})
		}
		return c.JSON(role)
	})

	app.Get("/roles", func(c *fiber.Ctx) error {
		roles, err := auth.GetAllRoles()
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Error getting roles"})
		}
		return c.JSON(roles)
	})

	// app.Put("/roles/:slug", func(c *fiber.Ctx) error {
	// 	roleSlug := c.Params("slug")
	// 	var updatedRole authority.Role
	// 	if err := c.BodyParser(&updatedRole); err != nil {
	// 		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Bad request"})
	// 	}
	// 	updatedRole.Slug = roleSlug
	// 	err := auth.UpdateRole(updatedRole)
	// 	if err != nil {
	// 		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to update role"})
	// 	}
	// 	return c.JSON(fiber.Map{"message": "Role updated successfully"})
	// })

	app.Delete("/roles/:slug", func(c *fiber.Ctx) error {
		roleSlug := c.Params("slug")
		err := auth.DeleteRole(roleSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to delete role"})
		}
		return c.JSON(fiber.Map{"message": "Role deleted successfully"})
	})

	app.Post("/permissions", func(c *fiber.Ctx) error {
		var permission authority.Permission
		if err := c.BodyParser(&permission); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Bad request"})
		}
		err := auth.CreatePermission(permission)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to create permission"})
		}
		return c.JSON(fiber.Map{"message": "Permission created successfully"})
	})

	// app.Get("/permissions/:slug", func(c *fiber.Ctx) error {
	// 	permissionSlug := c.Params("slug")
	// 	permission, err := auth.GetPermissionBySlug(permissionSlug)
	// 	if err != nil {
	// 		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Permission not found"})
	// 	}
	// 	return c.JSON(permission)
	// })

	app.Get("/permissions", func(c *fiber.Ctx) error {
		permissions, err := auth.GetAllPermissions()
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Error getting permissions"})
		}
		return c.JSON(permissions)
	})

	app.Delete("/permissions/:slug", func(c *fiber.Ctx) error {
		permissionSlug := c.Params("slug")
		err := auth.DeletePermission(permissionSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to delete permission"})
		}
		return c.JSON(fiber.Map{"message": "Permission deleted successfully"})
	})

	app.Post("/assign", func(c *fiber.Ctx) error {
		var assignment struct {
			RoleSlug    string   `json:"role_slug"`
			Permissions []string `json:"permissions"`
		}
		if err := c.BodyParser(&assignment); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Bad request"})
		}
		err := auth.AssignPermissionsToRole(assignment.RoleSlug, assignment.Permissions)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to assign permissions to role"})
		}
		return c.JSON(fiber.Map{"message": "Permissions assigned to role successfully"})
	})

	app.Post("/assign-role", func(c *fiber.Ctx) error {
		var userRole struct {
			UserID   int    `json:"user_id"`
			RoleSlug string `json:"role_slug"`
		}
		if err := c.BodyParser(&userRole); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Bad request"})
		}
		userID := userRole.UserID
		err := auth.AssignRoleToUser(userID, userRole.RoleSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to assign role to user"})
		}
		return c.JSON(fiber.Map{"message": "Role assigned to user successfully"})
	})

	app.Get("/check-role/:user_id/:role_slug", func(c *fiber.Ctx) error {
		userID, _ := strconv.Atoi(c.Params("user_id"))
		roleSlug := c.Params("role_slug")
		ok, err := auth.CheckUserRole(userID, roleSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Error checking user role"})
		}
		return c.JSON(fiber.Map{"has_role": ok})
	})

	app.Get("/check-permission/:user_id/:permission_slug", func(c *fiber.Ctx) error {
		userID, _ := strconv.Atoi(c.Params("user_id"))
		permissionSlug := c.Params("permission_slug")
		ok, err := auth.CheckUserPermission(userID, permissionSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Error checking user permission"})
		}
		return c.JSON(fiber.Map{"has_permission": ok})
	})

	app.Get("/check-role-permission/:role_slug/:permission_slug", func(c *fiber.Ctx) error {
		roleSlug := c.Params("role_slug")
		permissionSlug := c.Params("permission_slug")

		hasPermission, err := auth.CheckUserPermission(roleSlug, permissionSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Error checking role permission"})
		}

		return c.JSON(fiber.Map{"has_permission": hasPermission})
	})

	app.Delete("/revoke-role/:user_id/:role_slug", func(c *fiber.Ctx) error {
		userID, _ := strconv.Atoi(c.Params("user_id"))
		roleSlug := c.Params("role_slug")
		err := auth.RevokeUserRole(userID, roleSlug)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Error revoking user role"})
		}
		return c.JSON(fiber.Map{"message": "Role revoked from user successfully"})
	})

	app.Post("/assin-role/:user_id/:role_slug", func(c *fiber.Ctx) error {
		userID, _ := strconv.Atoi(c.Params("user_id"))
		roleSlug := c.Params("role_slug")

		// begin a transaction session
		tx := auth.BeginTX()
		// create role
		err := tx.CreateRole(authority.Role{
			Name: roleSlug,
			Slug: roleSlug,
		})
		if err != nil {
			tx.Rollback() // transaction rollback incase of error
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"message": "creating role",
				"error":   err.Error(),
			})
		}

		// create permissions
		err = tx.CreatePermission(authority.Permission{
			Name: "Permission 1",
			Slug: "permission-1",
		})
		if err != nil {
			tx.Rollback() // transaction rollback incase of error
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"message": "creating permission",
				"error":   err.Error(),
			})
		}

		// assign the permissions to the role
		err = tx.AssignPermissionsToRole("role-1", []string{
			"permission-1",
			"permission-2",
			"permission-3",
		})

		if err != nil {
			tx.Rollback() // transaction rollback incase of error
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"message": "assigning permission to role",
				"error":   err.Error(),
			})
		}
		// assign a role to user (user id = 1)
		err = tx.AssignRoleToUser(userID, roleSlug)
		if err != nil {
			tx.Rollback() // transaction rollback incase of error
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"message": "Error revoking user role",
				"error":   err.Error(),
			})
		}

		// commit the operations to the database
		tx.Commit()
		return c.JSON(fiber.Map{"message": "Role revoked from user successfully"})
	})
}
