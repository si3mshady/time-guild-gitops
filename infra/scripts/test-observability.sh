#!/bin/bash
# Telemetry and Observability Verification script for TimeGuild Day 1
# This script simulates bulk activity by creating 18 mock accounts using the "elliot" pattern.
set -e

APP_URL=${1:-"http://localhost:3000"}
COOKIE_FILE="test_cookies.txt"

echo "=== STARTING BULK OBSERVABILITY TEST GENERATION (18 USERS) ==="

for i in {1..18}
do
  USERNAME="elliot-$i"
  EMAIL="elliot-$i@linkedin-test.com"
  PASSWORD="password123"
  
  echo -e "\n--- Processing User: $USERNAME ---"
  
  # Clean up any stale test cookies
  rm -f "$COOKIE_FILE"

  # 1. Signup (Creates [SIGNUP] log)
  echo "1. Registering user..."
  SIGNUP_RES=$(curl -s -X POST "$APP_URL/api/auth/signup" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"username\":\"$USERNAME\"}")
  echo "$SIGNUP_RES"
  
  # 2. Onboard as Creator (Creates [TENANT] and [CREATOR] logs)
  echo "2. Onboarding creator profile..."
  CREATOR_RES=$(curl -s -X POST "$APP_URL/api/creators" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -d "{\"role\":\"creator\",\"displayName\":\"Elliot Tester $i\",\"bio\":\"Validating Prometheus & Loki labels for Elliot account $i\",\"tags\":[\"linkedin-test\",\"elliot\"],\"price\":100}")
  echo "$CREATOR_RES"

  # 3. Sign In (Creates [LOGIN] log)
  # Wiping cookie to force a clean login request
  rm -f "$COOKIE_FILE"
  echo "3. Logging in..."
  LOGIN_RES=$(curl -s -X POST "$APP_URL/api/auth/signin" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
  echo "$LOGIN_RES"

  # 4. Stripe Connect Account Creation (Creates [STRIPE] log)
  echo "4. Generating Stripe Connect account..."
  STRIPE_ONBOARD_RES=$(curl -s -X POST "$APP_URL/api/stripe/connect" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -d '{"action":"onboard"}')
  echo "$STRIPE_ONBOARD_RES"

  # 5. Stripe Connect Simulation Complete (Creates [STRIPE] complete log)
  echo "5. Simulating Stripe onboarding completion..."
  STRIPE_SIMULATE_RES=$(curl -s -X POST "$APP_URL/api/stripe/connect" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -d '{"action":"simulate_complete"}')
  echo "$STRIPE_SIMULATE_RES"
done

echo -e "\n=== STEP 6: TELEMETRY METRICS VERIFICATION ==="
echo "Checking Prometheus metrics endpoint for tenant labels..."
sleep 1
METRICS_OUTPUT=$(curl -s "$APP_URL/api/metrics" | grep "elliot-" || true)

if [ -n "$METRICS_OUTPUT" ]; then
  echo "Success! Found tenant-specific metrics:"
  echo "$METRICS_OUTPUT" | head -n 10
  echo "... (showing first 10 metrics)"
else
  echo "Warning: No metrics containing 'elliot-' labels found yet. Verify database records."
fi

# Clean up session file
rm -f "$COOKIE_FILE"
echo -e "\n=== Bulk test sequence finished successfully (18 users generated) ==="
