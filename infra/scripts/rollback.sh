#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-"timeguild-prod"}
REVISION=${2:-""} # Rollback revision, defaults to previous if empty

if [ -z "${REVISION}" ]; then
  echo "==> Rolling back timeguild in namespace ${NAMESPACE} to previous revision..."
  helm rollback timeguild --namespace "${NAMESPACE}"
else
  echo "==> Rolling back timeguild in namespace ${NAMESPACE} to revision ${REVISION}..."
  helm rollback timeguild "${REVISION}" --namespace "${NAMESPACE}"
fi
echo "==> Rollback initiated."
