#!/usr/bin/env bash
set -e

echo "⚠️  DEVSECOPS LAB: Starting Emergency / Weekend Teardown Sequence..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for ENV in prod staging dev; do
  if [ -d "$SCRIPT_DIR/environments/$ENV" ]; then
    echo "========================================="
    echo "🔥 Destroying Environment: $ENV"
    echo "========================================="
    cd "$SCRIPT_DIR/environments/$ENV"
    terraform init -input=false || true
    terraform destroy -auto-approve || echo "⚠️ Warning: destroy encountered issues in $ENV, review console output."
  fi
done

echo "✅  Teardown complete across dev, staging, and prod."
