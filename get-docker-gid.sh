#!/bin/bash
# Get the Docker group ID from the host system
# This ensures the Rundeck container can access the Docker socket

# Check if docker group exists and get its GID
if getent group docker >/dev/null 2>&1; then
    # Docker group exists, get its GID
    DOCKER_GID=$(getent group docker | cut -d: -f3)
    echo "$DOCKER_GID"
else
    # Docker group doesn't exist, use a common default
    # This might happen in some Docker-in-Docker scenarios
    echo "999"
fi