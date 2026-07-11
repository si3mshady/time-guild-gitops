#!/usr/bin/env bash
set -euo pipefail

REGISTRY=${1:-"ghcr.io"}
IMAGE_NAME=${2:-"si3mshady/time-guild"}
TAG=${3:-"latest"}

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "==> Pushing Container Image: ${FULL_IMAGE}..."
docker push "${FULL_IMAGE}"
echo "==> Push Completed."
