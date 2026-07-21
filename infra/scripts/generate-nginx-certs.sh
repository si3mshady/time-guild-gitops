#!/usr/bin/env bash

# ==============================================================================
# Time Guild Self-Signed TLS/SSL Certificate Generator
# Generates 2048-bit RSA Wildcard Certificates for local Nginx testing
# ==============================================================================

set -e

CERT_DIR="${1:-infra/docker/nginx/certs}"
mkdir -p "${CERT_DIR}"

echo "========================================================================"
echo "🔒 Generating Nginx Wildcard TLS/SSL Certificate Pair"
echo "========================================================================"
echo "Output Directory: ${CERT_DIR}"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/timeguild.key" \
  -out "${CERT_DIR}/timeguild.crt" \
  -subj "/C=US/ST=State/L=City/O=TimeGuild/CN=*.timeguild.xyz" \
  -addext "subjectAltName=DNS:*.timeguild.xyz,DNS:timeguild.xyz,DNS:localhost,IP:127.0.0.1"

echo "✅ Created Certificate: ${CERT_DIR}/timeguild.crt"
echo "✅ Created Private Key:  ${CERT_DIR}/timeguild.key"
echo "========================================================================"
