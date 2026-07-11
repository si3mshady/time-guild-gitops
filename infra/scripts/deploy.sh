#!/usr/bin/env bash
set -euo pipefail

# Infrastructure folder reference
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELM_CHART="${INFRA_DIR}/helm/timeguild"

ENV=${1:-"lab"} # Options: dev, lab, prod
NAMESPACE=${2:-"timeguild-prod"}

VALUES_FILE=""
case $ENV in
  dev)
    VALUES_FILE="${HELM_CHART}/values-dev.yaml"
    ;;
  lab)
    VALUES_FILE="${HELM_CHART}/values-lab.yaml"
    ;;
  prod)
    VALUES_FILE="${HELM_CHART}/values-prod.yaml"
    ;;
  *)
    echo "Error: Invalid environment '$ENV'. Choose: dev, lab, prod"
    exit 1
    ;;
esac

echo "==> Deploying Time Guild (${ENV}) using Helm in Namespace '${NAMESPACE}'..."
helm upgrade --install timeguild "${HELM_CHART}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f "${HELM_CHART}/values.yaml" \
  -f "${VALUES_FILE}"

echo "==> Deployment initiated successfully."
