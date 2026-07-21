#!/usr/bin/env bash

# ==============================================================================
# Time Guild Live Traffic & Security Telemetry Generator
# ==============================================================================
# Generates synthetic traffic to test:
# 1. Incoming Nginx HTTPS Requests/sec (200 OK)
# 2. Web Application Firewall (WAF) Attack Probes (403 Forbidden)
# 3. API Rate Limiting Bursts (429 Too Many Requests)
# 4. Live Grafana Loki Observation Stream

set -e

# Target domain and IP mapping default to Kubernetes Ingress setup
DOMAIN="${1:-timeguild.xyz}"
IP_ADDR="${2:-127.0.0.1}"
ROUNDS="${3:-0}" # 0 = run continuously until Ctrl+C

# ANSI Color Codes for terminal UI
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}========================================================================${NC}"
echo -e "${CYAN}${BOLD}🚀 Time Guild Nginx Live Traffic & Security Telemetry Generator${NC}"
echo -e "   Target Domain   : ${BOLD}https://${DOMAIN}${NC}"
echo -e "   Target IP       : ${BOLD}${IP_ADDR}${NC}"
echo -e "   Execution Mode  : $( [ "$ROUNDS" -eq 0 ] && echo -e "${GREEN}Continuous (Press Ctrl+C to stop)${NC}" || echo -e "${YELLOW}${ROUNDS} Rounds${NC}" )"
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

# Metrics Counters
TOTAL_200=0
TOTAL_403=0
TOTAL_429=0
ITERATION=0

# Clean Exit Handler
cleanup() {
  echo -e "\n\n${CYAN}${BOLD}========================================================================${NC}"
  echo -e "${CYAN}${BOLD}📊 Traffic Telemetry Batch Summary${NC}"
  echo -e "   🟢 Normal Requests (200 OK)         : ${GREEN}${TOTAL_200}${NC}"
  echo -e "   🔴 WAF Attack Probes (403 Blocked)  : ${RED}${TOTAL_403}${NC}"
  echo -e "   🟡 Rate Limit Bursts (429 Limited)  : ${YELLOW}${TOTAL_429}${NC}"
  echo -e "   Total HTTP Requests Dispatched      : $((TOTAL_200 + TOTAL_403 + TOTAL_429))"
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  exit 0
}

trap cleanup INT TERM

send_req() {
  local path="$1"
  local method="${2:-GET}"
  local user_agent="${3:-Mozilla/5.0}"
  
  local code
  code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 3 \
    --resolve "${DOMAIN}:443:${IP_ADDR}" \
    -X "${method}" \
    -A "${user_agent}" \
    "https://${DOMAIN}${path}" || echo "000")

  code=$(echo "$code" | tr -d '\r\n ' | tail -c 3)

  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
    TOTAL_200=$((TOTAL_200 + 1))
    echo -ne "${GREEN}🟢 [200 OK]${NC} "
  elif [ "$code" = "403" ]; then
    TOTAL_403=$((TOTAL_403 + 1))
    echo -ne "${RED}🔴 [403 WAF]${NC} "
  elif [ "$code" = "429" ]; then
    TOTAL_429=$((TOTAL_429 + 1))
    echo -ne "${YELLOW}🟡 [429 Limit]${NC} "
  else
    echo -ne "\033[0;35m🟣 [${code}]\033[0m "
  fi
}

while true; do
  ITERATION=$((ITERATION + 1))
  echo -e "${BOLD}Batch #${ITERATION}${NC} Dispatched:"
  
  # 1. Normal User Requests (200 OK)
  send_req "/" "GET"
  send_req "/api/creators" "GET"
  send_req "/api/slots" "GET"
  send_req "/marketplace" "GET"
  
  # 2. WAF Security Attack Probes (403 Forbidden)
  send_req "/api/creators?id=1%20UNION%20SELECT%20*%20FROM%20users" "GET"
  send_req "/.env" "GET"
  send_req "/" "GET" "sqlmap/1.0"
  send_req "/<script>alert('xss')</script>" "GET"
  
  # 3. Rate-Limit Bursts on Auth Endpoint (429 Too Many Requests)
  for i in {1..6}; do
    send_req "/api/auth/signin" "POST"
  done
  
  echo -e "\n  📊 ${BOLD}Totals so far${NC} -> 🟢 200 OK: ${GREEN}${TOTAL_200}${NC} | 🔴 403 WAF: ${RED}${TOTAL_403}${NC} | 🟡 429 Limit: ${YELLOW}${TOTAL_429}${NC}\n"
  
  if [ "$ROUNDS" -gt 0 ] && [ "$ITERATION" -ge "$ROUNDS" ]; then
    cleanup
  fi
  
  sleep 1.5
done
