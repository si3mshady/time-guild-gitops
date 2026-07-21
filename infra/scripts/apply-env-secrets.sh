#!/usr/bin/env bash
# infra/scripts/apply-env-secrets.sh
# Reads credentials from local .env and patches the Kubernetes Secret in K3s

set -euo pipefail

NAMESPACE=${1:-"timeguild-dev"}
SECRET_NAME="${NAMESPACE}-env-secrets"
DEPLOYMENT_NAME="${NAMESPACE}"
ENV_FILE="/home/si3mshady/time-guild/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Local .env file not found at $ENV_FILE" >&2
    exit 1
fi

echo "==> Loading credentials from $ENV_FILE..."
JWT_SECRET=$(grep '^JWT_SECRET=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
STRIPE_SECRET_KEY=$(grep '^STRIPE_SECRET_KEY=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=$(grep '^NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
SUPABASE_PUBLISHABLE_KEY=$(grep '^SUPABASE_PUBLISHABLE_KEY=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
DEEPSEEK_API_KEY=$(grep '^DEEPSEEK_API_KEY=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
STRIPE_WEBHOOK_SECRET=$(grep '^STRIPE_WEBHOOK_SECRET=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")

echo "==> Creating/Updating Kubernetes Secret ${SECRET_NAME} in namespace ${NAMESPACE}..."
kubectl create secret generic "${SECRET_NAME}" -n "${NAMESPACE}" \
  --from-literal=JWT_SECRET="${JWT_SECRET}" \
  --from-literal=STRIPE_SECRET_KEY="${STRIPE_SECRET_KEY}" \
  --from-literal=NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY="${NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY}" \
  --from-literal=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
  --from-literal=DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY}" \
  --from-literal=STRIPE_WEBHOOK_SECRET="${STRIPE_WEBHOOK_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Restarting deployment ${DEPLOYMENT_NAME} in namespace ${NAMESPACE}..."
kubectl rollout restart deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"

echo "==> Credentials successfully updated in Kubernetes!"
