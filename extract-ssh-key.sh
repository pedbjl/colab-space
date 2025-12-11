#!/bin/bash
# Script to extract SSH key from container to host
# Uses docker compose service name: python-gpu

SERVICE_NAME="python-gpu"

if [ ! -d "ssh-keys" ]; then
    mkdir -p ssh-keys
fi

echo "Extracting SSH key from container..."

# Get container name from docker compose
CONTAINER_NAME=$(docker compose ps -q ${SERVICE_NAME} 2>/dev/null | head -n 1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "Error: Container is not running."
    echo "Make sure the container is running: docker compose up -d"
    exit 1
fi

# Try to extract from mounted volume first, then from build location
if docker cp ${CONTAINER_NAME}:/etc/ssh/keys/docker-key.pem ssh-keys/docker-key.pem 2>/dev/null; then
    echo "Key found in mounted volume"
elif docker cp ${CONTAINER_NAME}:/root/.ssh/docker-key.pem ssh-keys/docker-key.pem 2>/dev/null; then
    echo "Key found in build location"
else
    echo "Error: Could not extract key from container."
    echo "Make sure the container is running: docker compose up -d"
    echo "The key should be available at:"
    echo "  - /etc/ssh/keys/docker-key.pem (mounted volume)"
    echo "  - /root/.ssh/docker-key.pem (build location)"
    exit 1
fi

chmod 600 ssh-keys/docker-key.pem
echo "SSH key extracted to ssh-keys/docker-key.pem"
echo ""
echo "You can now connect using:"
echo "  ssh -i ssh-keys/docker-key.pem -p 22 researcher@localhost"
echo ""
echo "Or if you've customized the SSH port in .env:"
echo "  ssh -i ssh-keys/docker-key.pem -p \${SSH_PORT} researcher@localhost"

