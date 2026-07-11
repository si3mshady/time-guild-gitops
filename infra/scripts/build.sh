#!/usr/bin/env bash
set -euo pipefail

# Root folder reference
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKERFILE="${ROOT_DIR}/infra/docker/Dockerfile.prod"

REGISTRY=${1:-"ghcr.io"}
IMAGE_NAME=${2:-"si3mshady/time-guild"}
TAG=${3:-"latest"}

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "==> Building Production Container Image: ${FULL_IMAGE}..."
docker build -f "${DOCKERFILE}" -t "${FULL_IMAGE}" "${ROOT_DIR}"
echo "==> Build Completed successfully."
