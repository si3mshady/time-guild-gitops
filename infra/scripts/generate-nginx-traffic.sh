#!/usr/bin/env bash

# ==============================================================================
# Time Guild Nginx Traffic & Log Stream Generator
# ==============================================================================
# Generates synthetic Nginx edge traffic:
# 1. Normal user visits & API calls (200 OK / 301 Redirect)
# 2. Web Application Firewall (WAF) attack probes (403 Forbidden)
# 3. Rate-limiting burst requests (429 Too Many Requests)

set -e

TARGET="${1:-https://localhost:443}"
DOMAIN="${2:-timeguild.xyz}"

echo "========================================================================"
echo "🚀 Generating Nginx Edge Traffic & Security Telemetry Logs"
echo "   Target: ${TARGET}"
echo "   Domain: ${DOMAIN}"
echo "========================================================================"

COUNT=0

while true; do
  COUNT=$((COUNT + 1))
  echo "[Iteration ${COUNT}] Sending traffic batch..."

  # 1. Normal User Browsing Traffic (200 OK)
  curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/" || true
  curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/api/creators" || true
  curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/api/slots" || true
  curl -k -s -o /dev/null -H "Host: tenant1.${DOMAIN}" "${TARGET}/" || true

  # 2. User Authentication Sign-In Attempt
  curl -k -s -o /dev/null -X POST -H "Host: ${DOMAIN}" "${TARGET}/api/auth/signin" || true

  # 3. WAF Security Attack Probes (Triggers 403 Forbidden Logs)
  curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/api/creators?id=1%20UNION%20SELECT%20*%20FROM%20users" || true
  curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/.env" || true
  curl -k -s -o /dev/null -A "sqlmap/1.0" -H "Host: ${DOMAIN}" "${TARGET}/" || true
  curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/<script>alert(1)</script>" || true

  # 4. Rate-Limit Burst (Triggers 429 Too Many Requests Logs)
  for i in {1..8}; do
    curl -k -s -o /dev/null -H "Host: ${DOMAIN}" "${TARGET}/api/auth/signin" || true
  done

  echo "  ✅ Batch sent. Check Grafana 'Live Nginx Edge JSON Access & Security Logs Stream'!"
  sleep 2
done
