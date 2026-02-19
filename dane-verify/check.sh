#!/bin/bash
set -e

# --- 1. Argument Handling ---
INPUT="${1:?Usage: check.sh <hostname>[:port] [-r resolver]}"
shift

# Split host and port
if [[ "$INPUT" == *":"* ]]; then
	TARGET="${INPUT%%:*}"
	PORT="${INPUT##*:}"
else
	TARGET="$INPUT"
	PORT=25
fi

RESOLVER="system"
while [[ $# -gt 0 ]]; do
	case "$1" in
	-r)
		RESOLVER="${2:?Error: -r requires a resolver address}"
		shift 2
		;;
	*)
		echo "ERROR: Unknown option $1"
		echo "Usage: check.sh <hostname>[:port] [-r resolver]"
		exit 1
		;;
	esac
done

# --- 2. Fetch DNS ---
if [[ "$RESOLVER" == "system" ]]; then
	DNS_FULL=$(dig +adflag +dnssec TLSA "_${PORT}._tcp.${TARGET}" 2>&1) || true
else
	DNS_FULL=$(dig "@${RESOLVER}" +adflag +dnssec TLSA "_${PORT}._tcp.${TARGET}" 2>&1) || true
fi

if [[ -z "$DNS_FULL" ]] || echo "$DNS_FULL" | grep -q "no servers could be reached" || echo "$DNS_FULL" | grep -q "communications error"; then
	echo "ERROR: DNS query failed for ${TARGET} using resolver ${RESOLVER}"
	[[ -n "$DNS_FULL" ]] && echo "$DNS_FULL"
	exit 1
fi

# Filter for the TLSA record line specifically
RECORD_LINE=$(echo "$DNS_FULL" | grep -v '^;' | grep -E "\s+IN\s+TLSA\s+" | head -n 1 | tr -d '()"' | tr '\n' ' ' || true)

if [[ -z "$RECORD_LINE" ]]; then
	echo "ERROR: No TLSA record found for _${PORT}._tcp.${TARGET} using resolver ${RESOLVER}"
	exit 1
fi

# Parsing Strategy:
# $5=Usage, $6=Selector, $7=Matching, $8+=Hash
USAGE=$(echo "$RECORD_LINE" | awk '{print $5}')
SELECTOR=$(echo "$RECORD_LINE" | awk '{print $6}')
MATCHING=$(echo "$RECORD_LINE" | awk '{print $7}')
DNS_HASH=$(echo "$RECORD_LINE" | awk '{for(i=8;i<=NF;i++) printf $i; print ""}' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

# Check DNSSEC status
[[ "$DNS_FULL" =~ "flags:".*"ad" ]] && DNSSEC_STATUS="secure" || DNSSEC_STATUS="insecure"

# --- 3. Fetch Live Certificate ---
TEMP_CHAIN=$(mktemp)
echo "QUIT" | openssl s_client -starttls smtp -connect "${TARGET}:${PORT}" \
	-servername "${TARGET}" -showcerts >"$TEMP_CHAIN" 2>/dev/null

if [[ "$USAGE" == "2" ]]; then
	CERT_PEM=$(awk '/BEGIN CERTIFICATE/{p=1;c++} p{a[c]=a[c] $0 "\n"} /END CERTIFICATE/{p=0} END{print a[c]}' "$TEMP_CHAIN")
else
	CERT_PEM=$(awk '/BEGIN CERTIFICATE/{p=1;c++} p{a[c]=a[c] $0 "\n"} /END CERTIFICATE/{p=0} END{print a[1]}' "$TEMP_CHAIN")
fi
rm "$TEMP_CHAIN"

if [[ -z "$CERT_PEM" ]]; then
	echo "ERROR: Could not retrieve certificate from server."
	exit 1
fi

# --- 4. Generate Live Hash ---
[[ "$SELECTOR" == "1" ]] && EXTRACT_CMD="openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER" || EXTRACT_CMD="openssl x509 -outform DER"

case "$MATCHING" in
1) HASH_CMD="openssl dgst -sha256 -hex" ;;
2) HASH_CMD="openssl dgst -sha512 -hex" ;;
0) HASH_CMD="xxd -p -c 0" ;;
*)
	echo "ERROR: Unsupported matching type $MATCHING"
	exit 1
	;;
esac

LIVE_HASH=$(echo "$CERT_PEM" | eval "$EXTRACT_CMD" | eval "$HASH_CMD" | sed 's/.* //; s/.*=//' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

# --- 5. Audit Log ---
echo "--------------------------------------------------------"
echo "DANE VERIFICATION AUDIT"
echo "--------------------------------------------------------"
echo "Target Host:    $TARGET"
echo "Resolver Used:  $RESOLVER"
echo "DNSSEC Status:  $DNSSEC_STATUS"
echo "Strategy:       Usage $USAGE, Selector $SELECTOR, Matching $MATCHING"
echo "DNS Hash:       $DNS_HASH"
echo "Live Hash:      $LIVE_HASH"
echo "--------------------------------------------------------"

if [[ -n "$DNS_HASH" && "$DNS_HASH" == "$LIVE_HASH" && "$DNSSEC_STATUS" == "secure" ]]; then
	echo "VERIFICATION: SUCCESS"
	exit 0
else
	echo "VERIFICATION: FAILURE"
	exit 1
fi
