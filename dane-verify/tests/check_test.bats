#!/usr/bin/env bats

# Setup helper variables
setup() {
  MOCK_DIG_OUTPUT=""
  MOCK_OPENSSL_CLIENT_OUTPUT=""
  MOCK_OPENSSL_X509_OUTPUT=""
  MOCK_OPENSSL_DGST_OUTPUT=""
  
  # Ensure we start with empty/default globals
  TARGET=""
  PORT=25
  RESOLVER="system"
}

# Override CLI commands with bash functions to act as mocks
dig() {
  echo "$MOCK_DIG_OUTPUT"
}

openssl() {
  if [[ "$1" == "s_client" ]]; then
    echo "$MOCK_OPENSSL_CLIENT_OUTPUT"
  elif [[ "$1" == "x509" ]]; then
    if [[ "$*" == *" -pubkey "* ]]; then
      echo -n "MOCK_PUBKEY"
    else
      echo -n "MOCK_CERT_DER"
    fi
  elif [[ "$1" == "pkey" ]]; then
    echo -n "MOCK_PUBKEY_DER"
  elif [[ "$1" == "dgst" ]]; then
    local input
    input=$(cat)
    if [[ "$*" == *"-sha256"* ]]; then
      if [[ "$input" == *"MOCK_PUBKEY_DER"* ]]; then
        echo "SHA256(stdin)= E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
      else
        echo "SHA256(stdin)= 9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08"
      fi
    elif [[ "$*" == *"-sha512"* ]]; then
      echo "SHA512(stdin)= 9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c1b11502419514fcfc88a8d56b57731"
    fi
  else
    command openssl "$@"
  fi
}

xxd() {
  if [[ "$*" == *"-p -c 0"* ]]; then
    local input
    input=$(cat)
    if [[ "$input" == *"MOCK_PUBKEY_DER"* ]]; then
      echo "4d4f434b5f5055424b45595f444552"
    else
      echo "4d4f434b5f434552545f444552"
    fi
  else
    command xxd "$@"
  fi
}

# --- Tests: Argument Parsing ---

@test "parse_args: hostname only uses default port 25" {
  source dane-verify/check.sh
  parse_args "mail.example.com"
  [ "$TARGET" = "mail.example.com" ]
  [ "$PORT" = "25" ]
  [ "$RESOLVER" = "system" ]
}

@test "parse_args: hostname with custom port" {
  source dane-verify/check.sh
  parse_args "mail.example.com:465"
  [ "$TARGET" = "mail.example.com" ]
  [ "$PORT" = "465" ]
}

@test "parse_args: custom resolver option -r" {
  source dane-verify/check.sh
  parse_args "mail.example.com" -r "1.1.1.1"
  [ "$TARGET" = "mail.example.com" ]
  [ "$RESOLVER" = "1.1.1.1" ]
}

@test "parse_args: error on unknown option" {
  source dane-verify/check.sh
  run parse_args "mail.example.com" --unknown-option
  [ "$status" -ne 0 ]
}

# --- Tests: DNS Fetching & Verification ---

@test "fetch_dns: extracts secure DNSSEC TLSA record" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  PORT=25
  MOCK_DIG_OUTPUT=";; flags: qr rd ra ad; QUERY: 1, ANSWER: 1
_25._tcp.mail.example.com. 3600 IN TLSA 3 1 1 E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

  fetch_dns
  [ "$DNSSEC_STATUS" = "secure" ]
  [ "${#TLSA_RECORDS[@]}" -eq 1 ]
  [[ "${TLSA_RECORDS[0]}" =~ "TLSA 3 1 1" ]]
}

@test "fetch_dns: marks insecure DNSSEC if ad flag is missing" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  PORT=25
  MOCK_DIG_OUTPUT=";; flags: qr rd ra; QUERY: 1, ANSWER: 1
_25._tcp.mail.example.com. 3600 IN TLSA 3 1 1 E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

  fetch_dns
  [ "$DNSSEC_STATUS" = "insecure" ]
}

@test "fetch_dns: fails when no TLSA records are found" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  PORT=25
  MOCK_DIG_OUTPUT=";; flags: qr rd ra ad; QUERY: 1, ANSWER: 0"
  
  run fetch_dns
  [ "$status" -ne 0 ]
}

# --- Tests: Cert Extraction ---

@test "fetch_certs: splits multiple certs into separate PEMs" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  PORT=25
  MOCK_OPENSSL_CLIENT_OUTPUT="depth=2 C = US, CN = Root
---
Certificate chain
 0 s:CN = mail.example.com
-----BEGIN CERTIFICATE-----
MOCK_LEAF
-----END CERTIFICATE-----
 1 s:CN = Intermediate
-----BEGIN CERTIFICATE-----
MOCK_INTERMEDIATE
-----END CERTIFICATE-----"

  fetch_certs
  [ "$CERT_COUNT" -eq 2 ]
  [ -f "$CERT_DIR/cert_1.pem" ]
  [ -f "$CERT_DIR/cert_2.pem" ]
  
  # Cleanup cert dir
  rm -rf "$CERT_DIR"
}

# --- Tests: DANE Verification Logic ---

@test "verify_dane: success with Usage 3, Selector 1, Matching 1 (Leaf SPKI SHA-256)" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  DNSSEC_STATUS="secure"
  
  # E3B0... is SHA256 of MOCK_PUBKEY_DER
  TLSA_RECORDS=("mail.example.com. 3600 IN TLSA 3 1 1 E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")
  
  # Create simulated CERT_DIR
  CERT_DIR=$(mktemp -d)
  echo "LEAF_PEM" > "$CERT_DIR/cert_1.pem"
  CERT_COUNT=1
  
  run verify_dane
  [ "$status" -eq 0 ]
  [[ "$output" =~ "VERIFICATION: SUCCESS" ]]
}

@test "verify_dane: success with Usage 2 (CA validation)" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  DNSSEC_STATUS="secure"
  
  # 9F86... is SHA256 of MOCK_CERT_DER (matching cert_2.pem)
  TLSA_RECORDS=("mail.example.com. 3600 IN TLSA 2 0 1 9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08")
  
  CERT_DIR=$(mktemp -d)
  echo "LEAF_PEM" > "$CERT_DIR/cert_1.pem"
  echo "CA_PEM" > "$CERT_DIR/cert_2.pem"
  CERT_COUNT=2
  
  run verify_dane
  [ "$status" -eq 0 ]
  [[ "$output" =~ "VERIFICATION: SUCCESS" ]]
}

@test "verify_dane: failure if DNSSEC is insecure" {
  source dane-verify/check.sh
  TARGET="mail.example.com"
  DNSSEC_STATUS="insecure" # Insecure DNSSEC should fail validation
  TLSA_RECORDS=("mail.example.com. 3600 IN TLSA 3 1 1 E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")
  
  CERT_DIR=$(mktemp -d)
  echo "LEAF_PEM" > "$CERT_DIR/cert_1.pem"
  CERT_COUNT=1
  
  run verify_dane
  [ "$status" -eq 1 ]
  [[ "$output" =~ "VERIFICATION: FAILURE" ]]
}
