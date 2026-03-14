#!/bin/bash
set -euo pipefail

trap 'wg-quick down wg0 &>/dev/null' EXIT

EXPECTED_HTTP_CODE=200
TIMEOUT=10
VERBOSE=false

while getopts "s:t:v" opt; do
    case $opt in
        s) EXPECTED_HTTP_CODE=$OPTARG ;;
        t) TIMEOUT=$OPTARG ;;
        v) VERBOSE=true ;;
        *) ;;
    esac
done
shift $((OPTIND - 1))

TARGET_URL=${1:-}

if [ -z "$TARGET_URL" ]; then
    echo "Usage: docker run ... wg-verify [-v] [-s expected_http_code] [-t timeout] <URL>"
    echo "  -v  Verbose output"
    echo "  -s  Expected HTTP status code (default: 200)"
    echo "  -t  Timeout in seconds, applied separately to handshake and request (default: 10)"
    exit 1
fi

echo "[1/3] Starting WireGuard tunnel..."
if $VERBOSE; then
    wg-quick up wg0
else
    wg-quick up wg0 &>/dev/null
fi

echo "[2/3] Checking handshake..."
DEADLINE=$(($(date +%s) + TIMEOUT))
while true; do
    HANDSHAKE=$(wg show wg0 latest-handshakes | awk '{print $2}')
    NOW=$(date +%s)
    if [ -n "$HANDSHAKE" ] && [ "$HANDSHAKE" -ne 0 ] && [ $((NOW - HANDSHAKE)) -le 30 ]; then
        break
    fi
    if [ "$NOW" -ge "$DEADLINE" ]; then
        echo "❌ No handshake after ${TIMEOUT}s. Server may be down or port is blocked."
        exit 1
    fi
    sleep 1
done
echo "✅ Handshake successful."

echo "[3/3] Requesting $TARGET_URL..."
WG_IP=$(ip -4 addr show wg0 | awk '/inet / {print $2}' | cut -d/ -f1)
if $VERBOSE; then
    echo "  Source IP: $WG_IP"
fi
HTTP_CODE=$(curl --interface "$WG_IP" -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" "$TARGET_URL")

if [ "$HTTP_CODE" -eq "$EXPECTED_HTTP_CODE" ]; then
    echo "✅ HTTP $HTTP_CODE — passed."
    exit 0
else
    echo "❌ HTTP $HTTP_CODE (expected $EXPECTED_HTTP_CODE)."
    exit 1
fi
