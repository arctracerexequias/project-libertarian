const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const serviceName = process.argv[2];
if (!serviceName) {
  console.error('Usage: node scaffold_service.cjs <service-name>');
  process.exit(1);
}

const rootDir = process.cwd();
const targetDir = path.join(rootDir, serviceName);

if (fs.existsSync(targetDir)) {
  console.error(`Error: Directory ${serviceName} already exists.`);
  process.exit(1);
}

console.log(`🚀 Scaffolding new service: ${serviceName}...`);

// 1. Create Directories
const dirs = [
  '',
  'internal/domain',
  'internal/repository/postgres',
  'internal/service',
  'internal/handler/http',
];

dirs.forEach(d => fs.mkdirSync(path.join(targetDir, d), { recursive: true }));

// 2. Generate go.mod
const goModContent = `module github.com/service-marketplace/${serviceName}

go 1.25.0
`;
fs.writeFileSync(path.join(targetDir, 'go.mod'), goModContent);

// 3. Generate main.go
const mainGoContent = `package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/service-marketplace/shared-contracts/pkg/database"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://user:password@localhost:5432/marketplace"
	}

	dbPool, err := database.ConnectPostgres(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "up", "service": "${serviceName}"})
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("${serviceName} starting on port %s", port)
	r.Run("0.0.0.0:" + port)
}
`;
fs.writeFileSync(path.join(targetDir, 'main.go'), mainGoContent);

// 4. Generate Dockerfile
const dockerfileContent = `# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app

COPY shared-contracts /app/shared-contracts
COPY ${serviceName} /app/${serviceName}
WORKDIR /app/${serviceName}

RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/${serviceName}/main .
EXPOSE 8080
CMD ["./main"]
`;
fs.writeFileSync(path.join(targetDir, 'Dockerfile'), dockerfileContent);

// 5. Link Shared Contracts
console.log('🔗 Linking shared-contracts...');
try {
  execSync(`go mod edit -require github.com/service-marketplace/shared-contracts@v0.0.0`, { cwd: targetDir });
  execSync(`go mod edit -replace github.com/service-marketplace/shared-contracts@v0.0.0=../shared-contracts`, { cwd: targetDir });
  // We'll run go mod tidy later via the agent to ensure all deps are resolved
} catch (e) {
  console.warn('Warning: Could not link shared-contracts automatically.');
}

// 6. Update go.work
const goWorkPath = path.join(rootDir, 'go.work');
if (fs.existsSync(goWorkPath)) {
  console.log('📝 Updating go.work...');
  let goWork = fs.readFileSync(goWorkPath, 'utf8');
  if (!goWork.includes(`./${serviceName}`)) {
    // Add to use block
    goWork = goWork.replace(/use \(/, `use (\n\t./${serviceName}`);
    fs.writeFileSync(goWorkPath, goWork);
  }
}

console.log(`✅ Successfully scaffolded ${serviceName}!`);
console.log(`Next steps:
1. Define entities in ${serviceName}/internal/domain
2. Implement Repository and Service
3. Run 'go mod tidy' in ${serviceName}
4. Add to docker-compose.yml`);
