#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-"timeguild-prod"}
DEPLOYMENT_NAME="timeguild-timeguild" # Helm release default fullname pattern is releaseName-chartName

echo "==> Restarting deployment ${DEPLOYMENT_NAME} in namespace ${NAMESPACE}..."
kubectl rollout restart deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}"
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}"
echo "==> Rollout Completed."
