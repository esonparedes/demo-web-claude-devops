#!/bin/bash

# Test Docker Image Locally
# Usage: ./scripts/test-local.sh [port]
#
# Example:
#   ./scripts/test-local.sh
#   ./scripts/test-local.sh 8080

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Port to expose
PORT=${1:-3000}
CONTAINER_NAME="demo-web-test"
IMAGE_NAME="demo-web-claude-devops:test"

print_info "Project root: $PROJECT_ROOT"
print_info "Port: $PORT"

# Change to project root
cd "$PROJECT_ROOT"

# Check if container is already running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    print_warning "Container $CONTAINER_NAME is already running"
    print_info "Stopping existing container..."
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
fi

# Build Docker image
print_info "Building Docker image..."
docker build -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    print_error "Failed to build Docker image"
    exit 1
fi

print_info "Successfully built Docker image"

# Run container
print_info "Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$PORT:3000" \
    -e NODE_ENV=development \
    -e PORT=3000 \
    "$IMAGE_NAME"

if [ $? -ne 0 ]; then
    print_error "Failed to start container"
    exit 1
fi

print_info "Container started successfully"
print_info "Container ID: $(docker ps -qf name=$CONTAINER_NAME)"

# Wait for application to start
print_info "Waiting for application to start..."
sleep 3

# Check if container is running
if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    print_error "Container is not running"
    print_info "Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Test the application
print_info "Testing application..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/)

if [ "$HTTP_STATUS" -eq 200 ]; then
    print_info "Application is responding correctly (HTTP $HTTP_STATUS)"
else
    print_error "Application returned HTTP $HTTP_STATUS"
    print_info "Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Test the API endpoint
print_info "Testing API endpoint..."
API_RESPONSE=$(curl -s "http://localhost:$PORT/api/search?q=test")
if echo "$API_RESPONSE" | grep -q "test"; then
    print_info "API endpoint is working correctly"
else
    print_warning "API endpoint response unexpected: $API_RESPONSE"
fi

# Display information
echo ""
print_info "=========================================="
print_info "Container is running successfully!"
print_info "=========================================="
print_info "Application URL: http://localhost:$PORT"
print_info "Container name: $CONTAINER_NAME"
print_info ""
print_info "Useful commands:"
print_info "  View logs:    docker logs -f $CONTAINER_NAME"
print_info "  Stop:         docker stop $CONTAINER_NAME"
print_info "  Remove:       docker rm $CONTAINER_NAME"
print_info "  Shell access: docker exec -it $CONTAINER_NAME sh"
print_info ""
print_info "Test the application in your browser:"
print_info "  http://localhost:$PORT"
print_info ""
print_info "When done testing, stop and remove the container:"
print_info "  docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
print_info "=========================================="
