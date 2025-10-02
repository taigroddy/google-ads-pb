#!/bin/bash

# Auto-generate gRPC code for Google Ads API
# Based on the GitHub Actions workflow in .github/workflows/generator.yml

set -e

# Configuration
VERSION="v21"  # Change this to the version you want to generate
GOOGLEAPIS_DIR="./googleapis"
OUTPUT_DIR="."
ADSLIB_PATH="${GOOGLEAPIS_DIR}/google/ads/googleads/${VERSION}"
API_CONFIG_PATH="${GOOGLEAPIS_DIR}/google/ads/googleads/${VERSION}/googleads_${VERSION}.yaml"
GRPC_CONFIG_PATH="${GOOGLEAPIS_DIR}/google/ads/googleads/${VERSION}/googleads_grpc_service_config.json"

echo "==> Auto-generating gRPC code for Google Ads API ${VERSION}"

# Check if required tools are installed
command -v protoc >/dev/null 2>&1 || { echo "protoc is required but not installed. Run: brew install protobuf"; exit 1; }

# Add Go bin to PATH if not already there
GOBIN_PATH="$(go env GOPATH)/bin"
if [[ ":$PATH:" != *":$GOBIN_PATH:"* ]]; then
    export PATH="$PATH:$GOBIN_PATH"
    echo "Added $GOBIN_PATH to PATH"
fi

command -v protoc-gen-go >/dev/null 2>&1 || { echo "protoc-gen-go is required but not installed. Run: go install google.golang.org/protobuf/cmd/protoc-gen-go@latest"; exit 1; }
command -v protoc-gen-go-grpc >/dev/null 2>&1 || { echo "protoc-gen-go-grpc is required but not installed. Run: go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest"; exit 1; }
command -v protoc-gen-go_gapic >/dev/null 2>&1 || { echo "protoc-gen-go_gapic is required but not installed. Run: go install github.com/googleapis/gapic-generator-go/cmd/protoc-gen-go_gapic@latest"; exit 1; }

# Clone googleapis if not exists
if [ ! -d "$GOOGLEAPIS_DIR" ]; then
    echo "==> Cloning googleapis repository..."
    git clone --depth=1 --branch=master https://github.com/googleapis/googleapis.git "$GOOGLEAPIS_DIR"
fi

# Clone protobuf if needed (for google/protobuf imports)
if [ ! -d "$GOOGLEAPIS_DIR/google/protobuf" ]; then
    echo "==> Cloning protobuf repository for google/protobuf imports..."
    git clone --depth=1 --branch=main https://github.com/protocolbuffers/protobuf.git ./protobuf
    ln -sf "$(pwd)/protobuf/src/google/protobuf" "$GOOGLEAPIS_DIR/google/protobuf"
fi

# Check if the specified version exists
if [ ! -d "$ADSLIB_PATH" ]; then
    echo "Error: Version ${VERSION} not found in ${ADSLIB_PATH}"
    echo "Available versions:"
    ls -la "${GOOGLEAPIS_DIR}/google/ads/googleads/" | grep "^d" | awk '{print $NF}' | grep "^v"
    exit 1
fi

# Backup existing generated files
echo "==> Backing up existing generated files..."
mkdir -p ./backup
[ -d "./clients" ] && cp -r ./clients ./backup/ 2>/dev/null || true
[ -d "./common" ] && cp -r ./common ./backup/ 2>/dev/null || true
[ -d "./enums" ] && cp -r ./enums ./backup/ 2>/dev/null || true
[ -d "./errors" ] && cp -r ./errors ./backup/ 2>/dev/null || true
[ -d "./resources" ] && cp -r ./resources ./backup/ 2>/dev/null || true
[ -d "./services" ] && cp -r ./services ./backup/ 2>/dev/null || true

# Remove old generated files
echo "==> Removing old generated files..."
rm -rf ./clients ./common ./enums ./errors ./resources ./services

# Generate the code
echo "==> Running protoc to generate Go code..."
echo "Proto files location: $ADSLIB_PATH"
echo "API config: $API_CONFIG_PATH"
echo "gRPC config: $GRPC_CONFIG_PATH"

# Find all .proto files and generate code
PROTO_FILES=$(find "$ADSLIB_PATH" -name "*.proto")
if [ -z "$PROTO_FILES" ]; then
    echo "Error: No .proto files found in $ADSLIB_PATH"
    exit 1
fi

echo "Found $(echo "$PROTO_FILES" | wc -l) proto files"

protoc -I="$GOOGLEAPIS_DIR" \
    --go_out="$OUTPUT_DIR" \
    --go-grpc_out="$OUTPUT_DIR" \
    --go_gapic_out="$OUTPUT_DIR" \
    --go_gapic_opt 'go-gapic-package=clients;clients' \
    --go_gapic_opt "api-service-config=${API_CONFIG_PATH}" \
    --go_gapic_opt "grpc-service-config=${GRPC_CONFIG_PATH}" \
    $PROTO_FILES

# Fix the generated code structure
echo "==> Fixing generated code structure..."
BUILD_PATH="./google.golang.org/genproto/googleapis/ads/googleads/${VERSION}"
if [ -d "$BUILD_PATH" ]; then
    echo "Moving generated files from $BUILD_PATH to current directory..."
    cp -r "$BUILD_PATH"/* ./
    rm -rf ./google.golang.org
fi

# Update import paths in generated files
echo "==> Updating import paths..."
PUBLISH_PKG="github.com/taigroddy/google-ads-pb"
BUILD_PKG="google.golang.org/genproto/googleapis/ads/googleads/$VERSION"

find . -name '*.go' -not -path './backup/*' -not -path './googleapis/*' -not -path './protobuf/*' -exec sed -i '' "s|${BUILD_PKG}|${PUBLISH_PKG}|g" '{}' \;

# Clean up client test files and snippets
if [ -d "./clients" ]; then
    rm -f ./clients/*_test.go
    rm -rf ./clients/internal/snippets
    
    # Fix clients internal imports
    find ./clients -name '*.go' -exec sed -i '' 's|"clients"|"'"${PUBLISH_PKG}"'/clients"|g' '{}' \;
fi

# Fix known issues
echo "==> Fixing known issues..."
if [ -f "./resources/experiment_arm.pb.go" ]; then
    echo "Renaming experiment_arm.pb.go to experimentarm.pb.go"
    mv "./resources/experiment_arm.pb.go" "./resources/experimentarm.pb.go"
fi

# Update go.mod and format code
echo "==> Updating go.mod and formatting code..."
if [ ! -f go.mod ]; then
    go mod init "$PUBLISH_PKG"
fi

go mod tidy
go fmt ./...

# Test build
echo "==> Testing build..."
go build ./...

echo "==> Code generation completed successfully!"
echo "Generated directories: clients, common, enums, errors, resources, services"
echo ""
echo "To use different API version, edit the VERSION variable in this script."
echo "Available versions can be found at: https://github.com/googleapis/googleapis/tree/master/google/ads/googleads"