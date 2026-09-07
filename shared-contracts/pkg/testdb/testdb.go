// Package testdb provides isolated relational fixtures for repository regressions.
// It does not replace the separate full PostGIS migration check in CI.
package testdb

import (
	"context"
	"crypto/rand"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func Open(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("set TEST_DATABASE_URL for database regression tests")
	}
	ctx := context.Background()
	admin, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	schema := "test_" + strings.ToLower(rand.Text())
	if _, err = admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		admin.Close()
		t.Fatal(err)
	}
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	cfg.ConnConfig.RuntimeParams["search_path"] = schema + ",public"
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pool.Close(); admin.Exec(ctx, "DROP SCHEMA "+schema+" CASCADE"); admin.Close() })
	_, file, _, _ := runtime.Caller(0)
	fixture, err := os.ReadFile(filepath.Join(filepath.Dir(file), "fixture.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err = pool.Exec(ctx, string(fixture)); err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile(filepath.Join(filepath.Dir(file), "../../..", "database/migrations/000007_integrity_and_payment_checkout.up.sql"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err = pool.Exec(ctx, string(migration)); err != nil {
		t.Fatal(err)
	}
	return pool
}
func Exec(t *testing.T, pool *pgxpool.Pool, query string, args ...interface{}) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), query, args...); err != nil {
		t.Fatal(err)
	}
}

const Customer = "00000000-0000-0000-0000-000000000001"
const Provider = "00000000-0000-0000-0000-000000000002"
const Other = "00000000-0000-0000-0000-000000000003"
const Job = "00000000-0000-0000-0000-000000000011"
const Bid = "00000000-0000-0000-0000-000000000021"
