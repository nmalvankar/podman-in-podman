#!/bin/bash
set -e

# GitHub Actions Runner Entrypoint Script
# This script configures and starts the GitHub Actions runner

RUNNER_WORKDIR="/home/runner/actions-runner"

# Detect if running as root (common in ARC with privileged mode)
if [ "$(id -u)" -eq 0 ]; then
    echo "Running as root (privileged mode detected)"
    # Ensure runner directory is accessible
    if [ ! -d "${RUNNER_WORKDIR}" ]; then
        mkdir -p "${RUNNER_WORKDIR}"
    fi
    # Set ownership to root for privileged mode
    chown -R root:root "${RUNNER_WORKDIR}" 2>/dev/null || true
    
    # For root execution, Podman will use root storage or mounted volume
    # Check if Podman storage volume is mounted (ARC typically mounts to /home/runner/.local/share/containers)
    PODMAN_STORAGE="/home/runner/.local/share/containers"
    if [ -d "${PODMAN_STORAGE}" ] && [ ! -d "${PODMAN_STORAGE}/storage" ]; then
        echo "Initializing Podman storage in mounted volume..."
        podman system migrate --new-storage-path "${PODMAN_STORAGE}" 2>/dev/null || \
        mkdir -p "${PODMAN_STORAGE}/storage" || true
    fi
else
    # Running as non-root user (standalone mode)
    echo "Running as user: $(id -un)"
    # Initialize Podman storage for rootless Podman (if not already initialized)
    if [ ! -d "${HOME}/.local/share/containers/storage" ]; then
        echo "Initializing Podman storage..."
        podman system migrate
        echo "Podman storage initialized"
    fi
fi

# Check if running under ARC (Actions Runner Controller)
# ARC handles runner configuration automatically via ACTIONS_RUNNER_INPUT_URL and ACTIONS_RUNNER_INPUT_TOKEN
if [ -n "${ACTIONS_RUNNER_INPUT_URL}" ] || [ -n "${ACTIONS_RUNNER_INPUT_TOKEN}" ]; then
    echo "Running under Actions Runner Controller (ARC) - ARC will handle configuration"
    
    # Ensure runner directory exists and has correct permissions
    if [ ! -d "${RUNNER_WORKDIR}" ]; then
        mkdir -p "${RUNNER_WORKDIR}"
    fi
    
    # If running as root, ensure proper ownership
    if [ "$(id -u)" -eq 0 ]; then
        chown -R root:root "${RUNNER_WORKDIR}" 2>/dev/null || true
    fi
    
    # ARC will handle configuration via its own mechanism
    # Just ensure the runner directory exists and start the runner
    cd "${RUNNER_WORKDIR}"
    ./run.sh
    exit 0
fi

# Standalone mode: Check if runner is already configured
if [ ! -f "${RUNNER_WORKDIR}/.runner" ]; then
    echo "Configuring GitHub Actions runner..."
    
    # Validate required environment variables
    if [ -z "$GITHUB_REPOSITORY" ]; then
        echo "Error: GITHUB_REPOSITORY environment variable is required"
        echo "Example: GITHUB_REPOSITORY=owner/repo"
        exit 1
    fi
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "Error: GITHUB_TOKEN environment variable is required"
        echo "You can create a token at: https://github.com/settings/tokens"
        exit 1
    fi
    
    # Configure runner
    cd "${RUNNER_WORKDIR}"
    
    # Build configuration command
    CONFIG_CMD="./config.sh --url https://github.com/${GITHUB_REPOSITORY} --token ${GITHUB_TOKEN}"
    
    # Add optional parameters
    if [ -n "$RUNNER_NAME" ]; then
        CONFIG_CMD="${CONFIG_CMD} --name ${RUNNER_NAME}"
    else
        CONFIG_CMD="${CONFIG_CMD} --name runner-$(hostname)"
    fi
    
    if [ -n "$RUNNER_LABELS" ]; then
        CONFIG_CMD="${CONFIG_CMD} --labels ${RUNNER_LABELS}"
    fi
    
    if [ -n "$RUNNER_GROUP" ]; then
        CONFIG_CMD="${CONFIG_CMD} --runnergroup ${RUNNER_GROUP}"
    fi
    
    if [ "$RUNNER_EPHEMERAL" = "true" ]; then
        CONFIG_CMD="${CONFIG_CMD} --ephemeral"
    fi
    
    # Execute configuration
    eval "${CONFIG_CMD}"
    
    echo "Runner configured successfully!"
fi

# Start the runner
echo "Starting GitHub Actions runner..."
cd "${RUNNER_WORKDIR}"
./run.sh
