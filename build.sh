#!/bin/bash
# Build script for GitHub Actions runner container image using Podman

set -e

IMAGE_NAME="${IMAGE_NAME:-github-actions-runner}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building GitHub Actions runner image: ${FULL_IMAGE_NAME}"

# Build the image using Podman
podman build -t "${FULL_IMAGE_NAME}" -f Containerfile .

echo "Build complete!"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""
echo "To view the image:"
echo "  podman images ${IMAGE_NAME}"
echo ""
echo "To run the container:"
echo "  podman run -e GITHUB_REPOSITORY=owner/repo -e GITHUB_TOKEN=your_token ${FULL_IMAGE_NAME}"
