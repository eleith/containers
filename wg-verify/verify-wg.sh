#!/bin/bash
set -euo pipefail

trap 'wg-quick down wg0 2>/dev/null' EXIT

EXPECTED_HTTP_CODE=200

while getopts "s:" opt; do
    case $opt in
        s) EXPECTED_HTTP_CODE=$OPTARG ;;
        *) ;;
    esac
done
shift $((OPTIND - 1))

TARGET_URL=${1:-}

if [ -z "$TARGET_URL" ]; then
    echo "Usage: docker run ... vpn-verifier [-s expected_http_code] <URL>"
    echo "  -s  Expected HTTP status code (default: 200)"
    exit 1
fi

echo "[1/3] Starting WireGuard tunnel..."
# Start the tunnel using wg-quick
wg-quick up wg0

# Give it a few seconds to perform the handshake with Server A
sleep 5

echo "[2/3] Checking for active handshake..."
# Check if we have a recent handshake (within last 30 seconds)
HANDSHAKE=$(wg show wg0 latest-handshakes | awk '{print $2}')
NOW=$(date +%s)

if [ -z "$HANDSHAKE" ] || [ "$HANDSHAKE" -eq 0 ] || [ $((NOW - HANDSHAKE)) -gt 30 ]; then
    echo "❌ ERROR: No recent handshake detected. Server A might be down or port 51822 is blocked."
    exit 1
fi
echo "✅ Handshake successful."

echo "[3/3] Testing internal path to $TARGET_URL..."
# Perform the curl. We use -m to timeout quickly if the return path is broken.
# This validates Server B's routing and IP transparency.
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$TARGET_URL")

if [ "$HTTP_CODE" -eq "$EXPECTED_HTTP_CODE" ]; then
    echo "✅ SUCCESS: Internal service reached via VPN (HTTP $HTTP_CODE)."
    exit 0
else
    echo "❌ FAIL: Reached VPN but internal service returned HTTP $HTTP_CODE (expected $EXPECTED_HTTP_CODE) or timed out."
    echo "Check Server B routing and Nginx allow lists."
    exit 1
fi
