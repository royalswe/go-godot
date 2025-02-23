build:
	@echo "Building..."
	@cd server && go build -o main server/cmd/main.go

# Run the application
run:
	@cd server && go run cmd/main.go