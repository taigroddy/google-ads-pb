# Makefile for Google Ads API gRPC code generation

.PHONY: help install-tools generate clean test build

# Default version - change this to generate different API versions
VERSION ?= v21

help:
	@echo "Google Ads API gRPC Code Generation"
	@echo ""
	@echo "Available commands:"
	@echo "  make install-tools  - Install required protoc plugins"
	@echo "  make generate       - Generate gRPC code for API version $(VERSION)"
	@echo "  make clean          - Remove generated files and temporary directories"
	@echo "  make test           - Run tests on generated code"
	@echo "  make build          - Build all packages"
	@echo ""
	@echo "To generate for a different version:"
	@echo "  make generate VERSION=v20"
	@echo ""
	@echo "Available versions: v18, v19, v20, v21"

install-tools:
	@echo "Installing required protoc plugins..."
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.5
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
	go install github.com/googleapis/gapic-generator-go/cmd/protoc-gen-go_gapic@v0.53.1
	@echo "Tools installed successfully!"

generate:
	@echo "Generating gRPC code for Google Ads API $(VERSION)..."
	VERSION=$(VERSION) ./generate.sh

clean:
	@echo "Cleaning generated files and temporary directories..."
	rm -rf clients common enums errors resources services
	rm -rf googleapis protobuf backup
	rm -rf google.golang.org
	@echo "Clean completed!"

test:
	@echo "Running tests..."
	go test ./...

build:
	@echo "Building all packages..."
	go build ./...
	@echo "Build completed successfully!"

# Install protoc if not available (macOS only)
install-protoc:
	@command -v protoc >/dev/null 2>&1 || (echo "Installing protoc..." && brew install protobuf)

# Full setup: install all dependencies and generate code
setup: install-protoc install-tools generate
	@echo "Setup completed! You can now use the generated gRPC client library."