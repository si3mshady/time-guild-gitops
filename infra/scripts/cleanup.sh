#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-"timeguild-prod"}

echo "==> Uninstalling Time Guild Helm release..."
helm uninstall timeguild --namespace "${NAMESPACE}" || true

echo "==> Deleting namespace ${NAMESPACE}..."
kubectl delete namespace "${NAMESPACE}" || true

echo "==> Cleanup complete."
