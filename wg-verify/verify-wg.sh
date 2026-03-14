#!/bin/bash
set -euo pipefail

trap 'wg-quick down wg0 &>/dev/null' EXIT

EXPECTED_HTTP_CODE=200
VERBOSE=false

while getopts "s:v" opt; do
    case $opt in
        s) EXPECTED_HTTP_CODE=$OPTARG ;;
        v) VERBOSE=true ;;
        *) ;;
    esac
done
shift $((OPTIND - 1))

TARGET_URL=${1:-}

if [ -z "$TARGET_URL" ]; then
    echo "Usage: docker run ... wg-verify [-v] [-s expected_http_code] <URL>"
    echo "  -v  Verbose output"
    echo "  -s  Expected HTTP status code (default: 200)"
    exit 1
fi

echo "[1/3] Starting WireGuard tunnel..."
if $VERBOSE; then
    wg-quick up wg0
else
    wg-quick up wg0 &>/dev/null
fi

sleep 5

echo "[2/3] Checking handshake..."
HANDSHAKE=$(wg show wg0 latest-handshakes | awk '{print $2}')
NOW=$(date +%s)

if [ -z "$HANDSHAKE" ] || [ "$HANDSHAKE" -eq 0 ] || [ $((NOW - HANDSHAKE)) -gt 30 ]; then
    echo "❌ No recent handshake. Server may be down or port is blocked."
    exit 1
fi
echo "✅ Handshake successful."

echo "[3/3] Requesting $TARGET_URL..."
WG_IP=$(ip -4 addr show wg0 | awk '/inet / {print $2}' | cut -d/ -f1)
if $VERBOSE; then
    echo "  Source IP: $WG_IP"
fi
HTTP_CODE=$(curl --interface "$WG_IP" -s -o /dev/null -w "%{http_code}" -m 10 "$TARGET_URL")

if [ "$HTTP_CODE" -eq "$EXPECTED_HTTP_CODE" ]; then
    echo "✅ HTTP $HTTP_CODE — passed."
    exit 0
else
    echo "❌ HTTP $HTTP_CODE (expected $EXPECTED_HTTP_CODE)."
    exit 1
fi
