package database

import (
	"fmt"
	"minibase/config"
	"strconv"

	"github.com/harranali/authority"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB
var AUTH *authority.Authority

// ConnectDB connect to db
func ConnectDB() {
	p := config.Config("DB_PORT")
	port, err := strconv.ParseUint(p, 10, 32)

	if err != nil {
		panic("failed to parse database port")
	}

	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", config.Config("DB_HOST"), port, config.Config("DB_USER"), config.Config("DB_PASSWORD"), config.Config("DB_NAME"))

	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		panic("failed to connect database")
	}
	initAuthority()
}

func initAuthority() {
	AUTH = authority.New(authority.Options{
		TablesPrefix: "authority_",
		DB:           DB,
	})

	// create role
	_ = AUTH.CreateRole(authority.Role{
		Name: "Role 1",
		Slug: "role-1",
	})
}
