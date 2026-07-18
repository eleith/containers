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

# Extract all TLSA record lines
mapfile -t TLSA_RECORDS < <(echo "$DNS_FULL" | grep -v '^;' | grep -E "\s+IN\s+TLSA\s+" | tr -d '()"' || true)

if [[ ${#TLSA_RECORDS[@]} -eq 0 ]]; then
	echo "ERROR: No TLSA record found for _${PORT}._tcp.${TARGET} using resolver ${RESOLVER}"
	exit 1
fi

# Check DNSSEC status
[[ "$DNS_FULL" =~ "flags:".*"ad" ]] && DNSSEC_STATUS="secure" || DNSSEC_STATUS="insecure"

# --- 3. Fetch Live Certificate Chain ---
TEMP_CHAIN=$(mktemp)
echo "QUIT" | openssl s_client -starttls smtp -connect "${TARGET}:${PORT}" \
	-servername "${TARGET}" -showcerts >"$TEMP_CHAIN" 2>/dev/null

# Extract all individual PEM certificates into files
CERT_DIR=$(mktemp -d)
awk -v dir="$CERT_DIR" '
  /BEGIN CERTIFICATE/ {
    c++
    file = dir "/cert_" c ".pem"
  }
  /BEGIN CERTIFICATE/,/END CERTIFICATE/ {
    print $0 > file
  }
' "$TEMP_CHAIN"
rm "$TEMP_CHAIN"

CERT_COUNT=$(ls -1 "$CERT_DIR"/cert_*.pem 2>/dev/null | wc -l || echo 0)
if [[ $CERT_COUNT -eq 0 ]]; then
	echo "ERROR: Could not retrieve certificates from server."
	rm -rf "$CERT_DIR"
	exit 1
fi

# --- 4. Match Verification ---
MATCH_FOUND=false

echo "--------------------------------------------------------"
echo "DANE VERIFICATION AUDIT"
echo "--------------------------------------------------------"
echo "Target Host:    $TARGET"
echo "Resolver Used:  $RESOLVER"
echo "DNSSEC Status:  $DNSSEC_STATUS"
echo "Total Records:  ${#TLSA_RECORDS[@]}"
echo "Total Certs:    $CERT_COUNT"
echo "--------------------------------------------------------"

for RECORD_LINE in "${TLSA_RECORDS[@]}"; do
	USAGE=$(echo "$RECORD_LINE" | awk '{print $5}')
	SELECTOR=$(echo "$RECORD_LINE" | awk '{print $6}')
	MATCHING=$(echo "$RECORD_LINE" | awk '{print $7}')
	DNS_HASH=$(echo "$RECORD_LINE" | awk '{for(i=8;i<=NF;i++) printf $i; print ""}' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

	# Choose extraction command
	[[ "$SELECTOR" == "1" ]] && EXTRACT_CMD="openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER" || EXTRACT_CMD="openssl x509 -outform DER"

	# Choose hashing command
	case "$MATCHING" in
	1) HASH_CMD="openssl dgst -sha256 -hex" ;;
	2) HASH_CMD="openssl dgst -sha512 -hex" ;;
	0) HASH_CMD="xxd -p -c 0" ;;
	*) continue ;;
	esac

	# Validate based on Usage
	if [[ "$USAGE" == "3" ]]; then
		# Usage 3: Must match leaf certificate (cert_1.pem)
		LIVE_HASH=$(eval "$EXTRACT_CMD" < "$CERT_DIR/cert_1.pem" | eval "$HASH_CMD" | sed 's/.* //; s/.*=//' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
		if [[ "$DNS_HASH" == "$LIVE_HASH" ]]; then
			echo "MATCH: Found matching Usage 3 TLSA record (Leaf Certificate)"
			MATCH_FOUND=true
			break
		fi
	elif [[ "$USAGE" == "2" ]]; then
		# Usage 2: Can match any CA/intermediate certificate in the chain (cert_2.pem to cert_N.pem)
		for ((i=2; i<=CERT_COUNT; i++)); do
			LIVE_HASH=$(eval "$EXTRACT_CMD" < "$CERT_DIR/cert_${i}.pem" | eval "$HASH_CMD" | sed 's/.* //; s/.*=//' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
			if [[ "$DNS_HASH" == "$LIVE_HASH" ]]; then
				echo "MATCH: Found matching Usage 2 TLSA record (CA Certificate at depth $((i-1)))"
				MATCH_FOUND=true
				break 2
			fi
		done
	fi
done

rm -rf "$CERT_DIR"

if [[ "$MATCH_FOUND" == "true" && "$DNSSEC_STATUS" == "secure" ]]; then
	echo "VERIFICATION: SUCCESS"
	exit 0
else
	echo "VERIFICATION: FAILURE (Match: $MATCH_FOUND, DNSSEC: $DNSSEC_STATUS)"
	exit 1
fi

