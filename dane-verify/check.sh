#!/bin/bash
set -e

# Global defaults
TARGET=""
PORT=25
RESOLVER="system"
DNS_FULL=""
TLSA_RECORDS=()
DNSSEC_STATUS="insecure"
CERT_DIR=""
CERT_COUNT=0

parse_args() {
	if [[ -z "$1" ]]; then
		echo "Usage: check.sh <hostname>[:port] [-r resolver]" >&2
		return 1
	fi
	local INPUT="$1"
	shift

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
			echo "ERROR: Unknown option $1" >&2
			echo "Usage: check.sh <hostname>[:port] [-r resolver]" >&2
			return 1
			;;
		esac
	done
}

fetch_dns() {
	local dns_query_target="_${PORT}._tcp.${TARGET}"
	if [[ "$RESOLVER" == "system" ]]; then
		DNS_FULL=$(dig +adflag +dnssec TLSA "$dns_query_target" 2>&1) || true
	else
		DNS_FULL=$(dig "@${RESOLVER}" +adflag +dnssec TLSA "$dns_query_target" 2>&1) || true
	fi

	if [[ -z "$DNS_FULL" ]] || echo "$DNS_FULL" | grep -q "no servers could be reached" || echo "$DNS_FULL" | grep -q "communications error"; then
		echo "ERROR: DNS query failed for ${TARGET} using resolver ${RESOLVER}" >&2
		[[ -n "$DNS_FULL" ]] && echo "$DNS_FULL" >&2
		return 1
	fi

	mapfile -t TLSA_RECORDS < <(echo "$DNS_FULL" | grep -v '^;' | grep -E "\s+IN\s+TLSA\s+" | tr -d '()"' || true)

	if [[ ${#TLSA_RECORDS[@]} -eq 0 ]]; then
		echo "ERROR: No TLSA record found for $dns_query_target using resolver ${RESOLVER}" >&2
		return 1
	fi

	if [[ "$DNS_FULL" =~ "flags:".*"ad" ]]; then
		DNSSEC_STATUS="secure"
	else
		DNSSEC_STATUS="insecure"
	fi
}

fetch_certs() {
	local TEMP_CHAIN
	TEMP_CHAIN=$(mktemp)
	echo "QUIT" | openssl s_client -starttls smtp -connect "${TARGET}:${PORT}" \
		-servername "${TARGET}" -showcerts >"$TEMP_CHAIN" 2>/dev/null || true

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
	rm -f "$TEMP_CHAIN"

	CERT_COUNT=$(ls -1 "$CERT_DIR"/cert_*.pem 2>/dev/null | wc -l || echo 0)
	if [[ $CERT_COUNT -eq 0 ]]; then
		echo "ERROR: Could not retrieve certificates from server." >&2
		rm -rf "$CERT_DIR"
		return 1
	fi
}

verify_dane() {
	local MATCH_FOUND=false

	echo "--------------------------------------------------------"
	echo "DANE VERIFICATION AUDIT"
	echo "--------------------------------------------------------"
	echo "Target Host:    $TARGET"
	echo "Resolver Used:  $RESOLVER"
	echo "DNSSEC Status:  $DNSSEC_STATUS"
	echo "Total Records:  ${#TLSA_RECORDS[@]}"
	echo "Total Certs:    $CERT_COUNT"
	echo "--------------------------------------------------------"

	local RECORD_LINE
	for RECORD_LINE in "${TLSA_RECORDS[@]}"; do
		local USAGE SELECTOR MATCHING DNS_HASH EXTRACT_CMD HASH_CMD LIVE_HASH
		USAGE=$(echo "$RECORD_LINE" | awk '{print $5}')
		SELECTOR=$(echo "$RECORD_LINE" | awk '{print $6}')
		MATCHING=$(echo "$RECORD_LINE" | awk '{print $7}')
		DNS_HASH=$(echo "$RECORD_LINE" | awk '{for(i=8;i<=NF;i++) printf $i; print ""}' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]' || true)

		# Choose extraction command
		if [[ "$SELECTOR" == "1" ]]; then
			EXTRACT_CMD="openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER"
		else
			EXTRACT_CMD="openssl x509 -outform DER"
		fi

		# Choose hashing command
		case "$MATCHING" in
		1) HASH_CMD="openssl dgst -sha256 -hex" ;;
		2) HASH_CMD="openssl dgst -sha512 -hex" ;;
		0) HASH_CMD="xxd -p -c 0" ;;
		*)
			echo "WARNING: Unsupported matching type $MATCHING" >&2
			continue
			;;
		esac

		# Validate based on Usage
		if [[ "$USAGE" == "3" ]]; then
			if [[ ! -f "$CERT_DIR/cert_1.pem" ]]; then
				continue
			fi
			LIVE_HASH=$(eval "$EXTRACT_CMD" < "$CERT_DIR/cert_1.pem" | eval "$HASH_CMD" | sed 's/.* //; s/.*=//' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]' || true)
			if [[ "$DNS_HASH" == "$LIVE_HASH" ]]; then
				echo "MATCH: Found matching Usage 3 TLSA record (Leaf Certificate)"
				MATCH_FOUND=true
				break
			fi
		elif [[ "$USAGE" == "2" ]]; then
			local i
			for ((i=2; i<=CERT_COUNT; i++)); do
				if [[ ! -f "$CERT_DIR/cert_${i}.pem" ]]; then
					continue
				fi
				LIVE_HASH=$(eval "$EXTRACT_CMD" < "$CERT_DIR/cert_${i}.pem" | eval "$HASH_CMD" | sed 's/.* //; s/.*=//' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]' || true)
				if [[ "$DNS_HASH" == "$LIVE_HASH" ]]; then
					echo "MATCH: Found matching Usage 2 TLSA record (CA Certificate at depth $((i-1)))"
					MATCH_FOUND=true
					break 2
				fi
			done
		fi
	done

	if [[ -d "$CERT_DIR" ]]; then
		rm -rf "$CERT_DIR"
	fi

	if [[ "$MATCH_FOUND" == "true" && "$DNSSEC_STATUS" == "secure" ]]; then
		echo "VERIFICATION: SUCCESS"
		return 0
	else
		echo "VERIFICATION: FAILURE (Match: $MATCH_FOUND, DNSSEC: $DNSSEC_STATUS)"
		return 1
	fi
}

# Guard entry point to allow testing/sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	parse_args "$@"
	fetch_dns
	fetch_certs
	verify_dane
fi
