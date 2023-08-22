package main

import (
	"log"
	"minibase/database"
	"minibase/middleware"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/proxy"
)

func main() {

	database.ConnectDB()
	// initiate authority

	app := fiber.New(fiber.Config{
		Prefork:       true,
		CaseSensitive: true,
		StrictRouting: true,
		ServerHeader:  "Fiber",
		AppName:       "App Name",
	})

	app.Use(cors.New())

	api := app.Group("/api", logger.New())
	api.Get("/", graphql)
	api.Get("/graphql", middleware.Protected(), graphql)
	log.Fatal(app.Listen(":3000"))
}

func graphql(c *fiber.Ctx) error {
	// Middleware
	url := "http://localhost:3001/rpc/graphql"
	if err := proxy.Do(c, url); err != nil {
		return err
	}
	// Remove Server header from response
	c.Response().Header.Del(fiber.HeaderServer)
	return nil
}
