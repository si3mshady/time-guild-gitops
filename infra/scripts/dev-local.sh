#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPTS_DIR}/../compose/docker-compose.yaml"

ACTION=${1:-"up"} # Options: up, down, restart, logs

case $ACTION in
  up)
    echo "==> Launching Local Docker Compose Environment..."
    docker compose -f "${COMPOSE_FILE}" up -d --build
    echo "==> App running at http://localhost:3000"
    ;;
  down)
    echo "==> Shutting down local compose environment..."
    docker compose -f "${COMPOSE_FILE}" down -v
    ;;
  logs)
    docker compose -f "${COMPOSE_FILE}" logs -f
    ;;
  restart)
    echo "==> Restarting container services..."
    docker compose -f "${COMPOSE_FILE}" restart
    ;;
  *)
    echo "Error: Invalid action '$ACTION'. Choose: up, down, logs, restart"
    exit 1
    ;;
esac
