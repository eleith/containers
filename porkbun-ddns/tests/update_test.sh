#!/bin/bash
set -Eeuo pipefail

SCRIPT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/update.sh

setup() {
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf "$WORK_DIR"' EXIT
    CREDENTIALS_FILE=$WORK_DIR/porkbun.json
    export REQUEST_LOG=$WORK_DIR/requests.jsonl CURL_ARGS=$WORK_DIR/curl-args
    : > "$REQUEST_LOG"
    : > "$CURL_ARGS"
    printf '%s\n' '{"apikey":"test-key","secretapikey":"test-secret"}' > "$CREDENTIALS_FILE"
    export PING_RESPONSE='{"status":"SUCCESS","yourIp":"203.0.113.10"}'
    export DNS_RESPONSE='{"status":"SUCCESS","records":[{"id":"123","name":"home.example.com","type":"A","content":"198.51.100.20","ttl":"600"}]}'
    export EDIT_RESPONSE='{"status":"SUCCESS"}'
    export FAIL_STAGE=''
}

# Exported into a fresh Bash process so errexit behaves as it does in production.
# Only HTTP is mocked; request construction and response parsing use real jq.
curl() {
    local url=${!#} stage
    printf '%s\n' "$@" >> "$CURL_ARGS"
    jq -c --arg url "$url" '{url: $url, body: .}' >> "$REQUEST_LOG"
    case "$url" in
        */ping) stage=ping ;;
        */dns/retrieveByNameType/*) stage=retrieve ;;
        */dns/edit/*) stage=edit ;;
        *) printf 'Unexpected URL: %s\n' "$url" >&2; return 1 ;;
    esac
    if [[ $FAIL_STAGE == "$stage" ]]; then
        printf 'Mock HTTP failure\n' >&2
        return 22
    fi
    case "$stage" in
        ping) printf '%s\n' "$PING_RESPONSE" ;;
        retrieve) printf '%s\n' "$DNS_RESPONSE" ;;
        edit) printf '%s\n' "$EDIT_RESPONSE" ;;
    esac
}
export -f curl

run_updater() {
    status=0
    output=$(bash -c 'source "$1"; CREDENTIALS_FILE=$2; shift 2; main "$@"' \
        _ "$SCRIPT" "$CREDENTIALS_FILE" "$@" 2>&1) || status=$?
}

assert_no_edit() {
    jq -es 'all(.[]; .url | contains("/dns/edit/") | not)' "$REQUEST_LOG" > /dev/null
}

updates_one_record_and_preserves_ttl() {
    run_updater example.com home
    [[ $status -eq 0 && $output == 'Updated: home.example.com A 198.51.100.20 -> 203.0.113.10' ]]
    jq -es 'length == 3 and
        .[0].url == "https://api-ipv4.porkbun.com/api/json/v3/ping" and
        .[1].url == "https://api-ipv4.porkbun.com/api/json/v3/dns/retrieveByNameType/example.com/A/home" and
        .[2].url == "https://api-ipv4.porkbun.com/api/json/v3/dns/edit/example.com/123" and
        .[2].body == {apikey: "test-key", secretapikey: "test-secret",
            name: "home", type: "A", content: "203.0.113.10", ttl: 600}' "$REQUEST_LOG" > /dev/null
}

unchanged_record_is_not_written() {
    DNS_RESPONSE=${DNS_RESPONSE/198.51.100.20/203.0.113.10}
    run_updater example.com home
    [[ $status -eq 0 && $output == 'Unchanged: home.example.com A 203.0.113.10' ]]
    [[ $(jq -s 'length' "$REQUEST_LOG") -eq 2 ]]
    assert_no_edit
}

dry_run_reports_change_without_writing() {
    FAIL_STAGE=edit
    run_updater --dry-run example.com home
    [[ $status -eq 0 && $output == 'Dry run: would update home.example.com A 198.51.100.20 -> 203.0.113.10' ]]
    [[ $(jq -s 'length' "$REQUEST_LOG") -eq 2 ]]
    assert_no_edit
}

dry_run_reports_unchanged_records() {
    DNS_RESPONSE=${DNS_RESPONSE/198.51.100.20/203.0.113.10}
    run_updater --dry-run example.com home
    [[ $status -eq 0 && $output == 'Unchanged: home.example.com A 203.0.113.10' ]]
    [[ $(jq -s 'length' "$REQUEST_LOG") -eq 2 ]]
    assert_no_edit
}

dry_run_supports_the_zone_apex() {
    DNS_RESPONSE=${DNS_RESPONSE/home.example.com/example.com}
    run_updater --dry-run example.com ''
    [[ $status -eq 0 && $output == 'Dry run: would update example.com A 198.51.100.20 -> 203.0.113.10' ]]
    [[ $(jq -s 'length' "$REQUEST_LOG") -eq 2 ]]
    assert_no_edit
}

dry_run_refuses_missing_or_multiple_records() {
    local original=$DNS_RESPONSE
    DNS_RESPONSE='{"status":"SUCCESS","records":[]}'
    run_updater --dry-run example.com home
    [[ $status -ne 0 && $output == *'found 0. Refusing to update.'* ]]
    DNS_RESPONSE=$(jq '.records += .records' <<< "$original")
    run_updater --dry-run example.com home
    [[ $status -ne 0 && $output == *'found 2. Refusing to update.'* ]]
    assert_no_edit
}

supports_the_zone_apex() {
    DNS_RESPONSE=${DNS_RESPONSE/home.example.com/example.com}
    run_updater example.com ''
    [[ $status -eq 0 ]]
    jq -es '.[1].url | endswith("/retrieveByNameType/example.com/A")' "$REQUEST_LOG" > /dev/null
    jq -es '.[2].body.name == ""' "$REQUEST_LOG" > /dev/null
}

supports_nested_names_and_multilabel_zones() {
    DNS_RESPONSE=$(jq '.records[0] |= (.name = "Services.Home.Example.co.uk." | .ttl = 1200)' <<< "$DNS_RESPONSE")
    run_updater EXAMPLE.CO.UK Services.Home
    [[ $status -eq 0 ]]
    jq -es '.[1].url | endswith("/example.co.uk/A/services.home")' "$REQUEST_LOG" > /dev/null
    jq -es '.[2].body.name == "services.home" and .[2].body.ttl == 1200' "$REQUEST_LOG" > /dev/null
}

refuses_missing_records() {
    DNS_RESPONSE='{"status":"SUCCESS","records":[]}'
    run_updater example.com home
    [[ $status -ne 0 && $output == *'found 0. Refusing to update.'* ]]
    assert_no_edit
}

refuses_multiple_records() {
    DNS_RESPONSE=$(jq '.records += .records' <<< "$DNS_RESPONSE")
    run_updater example.com home
    [[ $status -ne 0 && $output == *'found 2. Refusing to update.'* ]]
    assert_no_edit
}

rejects_invalid_arguments_before_network_access() {
    run_updater
    [[ $status -ne 0 && $output == *Usage:* ]]
    run_updater example.com
    [[ $status -ne 0 && $output == *Usage:* ]]
    run_updater example.com home extra
    [[ $status -ne 0 && $output == *Usage:* ]]
    run_updater --dry-run
    [[ $status -ne 0 && $output == *Usage:* ]]
    run_updater --dry-run example.com
    [[ $status -ne 0 && $output == *Usage:* ]]
    run_updater --dry-run example.com home extra
    [[ $status -ne 0 && $output == *Usage:* ]]
    local domain name
    for domain in 'example.com/' 'example.com?x=y' 'example.com.' '-example.com' 'ex..com'; do
        run_updater "$domain" home
        [[ $status -ne 0 ]]
    done
    for name in '../home' 'home#fragment' 'home/name' 'bad name'; do
        run_updater example.com "$name"
        [[ $status -ne 0 ]]
    done
    run_updater example.com "$(printf 'a%.0s' {1..64})"
    [[ $status -ne 0 ]]
    [[ ! -s $REQUEST_LOG ]]
}

rejects_invalid_credentials_without_echoing_them() {
    local credentials
    for credentials in '{"apikey":"test-secret"}' \
        '{"apikey":"test-secret","secretapikey":""}' \
        '{"apikey":false,"secretapikey":"test-secret"}' \
        'test-secret is not JSON' \
        $'{"apikey":"test-secret","secretapikey":"test-secret"}\n{}'; do
        printf '%s\n' "$credentials" > "$CREDENTIALS_FILE"
        run_updater example.com home
        [[ $status -ne 0 && $output != *test-secret* ]]
    done
    [[ ! -s $REQUEST_LOG ]]
}

rejects_missing_credentials() {
    rm "$CREDENTIALS_FILE"
    run_updater example.com home
    [[ $status -ne 0 && $output == *'Expected apikey and secretapikey'* ]]
    [[ ! -s $REQUEST_LOG ]]
}

rejects_invalid_public_addresses() {
    local ip
    for ip in '2001:db8::1' '256.0.0.1' '1.2.3' '1.2.3.4.5' '01.2.3.4' 'not an IP' ''; do
        : > "$REQUEST_LOG"
        PING_RESPONSE=$(jq -cn --arg ip "$ip" '{status: "SUCCESS", yourIp: $ip}')
        run_updater example.com home
        [[ $status -ne 0 && $output == *'valid IPv4 address'* ]]
        [[ $(jq -s 'length' "$REQUEST_LOG") -eq 1 ]]
    done
    PING_RESPONSE='{"status":"SUCCESS"}'
    run_updater example.com home
    [[ $status -ne 0 ]]
    assert_no_edit
}

rejects_invalid_record_lists() {
    local response
    for response in '{"status":"SUCCESS"}' '{"status":"SUCCESS","records":{}}'; do
        DNS_RESPONSE=$response
        run_updater example.com home
        [[ $status -ne 0 && $output == *'DNS record list'* ]]
    done
    assert_no_edit
}

rejects_unexpected_record_fields() {
    local original=$DNS_RESPONSE filter
    for filter in '.records[0].type = "AAAA"' \
        '.records[0].name = "other.example.com"' \
        '.records[0].id = "123/other"' \
        'del(.records[0].content)' \
        '.records[0].ttl = "bad"' \
        '.records[0].ttl = 0' \
        '.records[0].ttl = 1.5'; do
        DNS_RESPONSE=$(jq "$filter" <<< "$original")
        run_updater example.com home
        [[ $status -ne 0 ]]
    done
    assert_no_edit
}

stops_on_http_failures() {
    local stage expected
    expected=0
    for stage in ping retrieve edit; do
        expected=$((expected + 1))
        : > "$REQUEST_LOG"
        FAIL_STAGE=$stage
        run_updater example.com home
        [[ $status -ne 0 && $output == *'Request failed:'* && $output != *Updated:* ]]
        [[ $(jq -s 'length' "$REQUEST_LOG") -eq $expected ]]
    done
}

rejects_unsuccessful_or_malformed_api_responses() {
    local stage response
    for stage in PING_RESPONSE DNS_RESPONSE EDIT_RESPONSE; do
        local saved=${!stage}
        for response in '{"status":"ERROR","message":"test-secret"}' \
            'not JSON: test-secret' \
            $'{"status":"SUCCESS"}\n{"status":"SUCCESS"}'; do
            printf -v "$stage" '%s' "$response"
            run_updater example.com home
            [[ $status -ne 0 && $output == *'Unsuccessful or malformed API response:'* ]]
            [[ $output != *test-secret* && $output != *Updated:* ]]
        done
        printf -v "$stage" '%s' "$saved"
    done
}

keeps_credentials_out_of_arguments_and_logs() {
    printf '%s\n' '{"apikey":"key\"with\\escapes","secretapikey":"secret\"with\\escapes","content":"must-be-ignored"}' > "$CREDENTIALS_FILE"
    run_updater example.com home
    [[ $status -eq 0 && $output != *secret* && $output != *escapes* ]]
    if grep -Eq 'escapes|must-be-ignored' "$CURL_ARGS"; then
        return 1
    fi
    jq -es 'all(.[]; .body.apikey == "key\"with\\escapes" and
        .body.secretapikey == "secret\"with\\escapes") and
        (.[0].body | keys == ["apikey", "secretapikey"])' "$REQUEST_LOG" > /dev/null
}

uses_bounded_requests_without_redirects() {
    run_updater example.com home
    [[ $status -eq 0 ]]
    grep -Fxq -- '--connect-timeout' "$CURL_ARGS"
    grep -Fxq -- '--max-time' "$CURL_ARGS"
    grep -Fxq -- '--fail' "$CURL_ARGS"
    grep -Fxq -- '@-' "$CURL_ARGS"
    if grep -Eq -- '^(-L|--location)$' "$CURL_ARGS"; then
        return 1
    fi
}

reports_test_failure_location() {
    local diagnostic failure_status=0
    diagnostic=$(bash "${BASH_SOURCE[0]}" false 2>&1) || failure_status=$?
    [[ $failure_status -ne 0 && $diagnostic == *"FAIL false at ${BASH_SOURCE[0]}:"* ]]
    [[ $diagnostic =~ :[0-9]+$ ]]
}

TESTS=(
    updates_one_record_and_preserves_ttl
    unchanged_record_is_not_written
    dry_run_reports_change_without_writing
    dry_run_reports_unchanged_records
    dry_run_supports_the_zone_apex
    dry_run_refuses_missing_or_multiple_records
    supports_the_zone_apex
    supports_nested_names_and_multilabel_zones
    refuses_missing_records
    refuses_multiple_records
    rejects_invalid_arguments_before_network_access
    rejects_invalid_credentials_without_echoing_them
    rejects_missing_credentials
    rejects_invalid_public_addresses
    rejects_invalid_record_lists
    rejects_unexpected_record_fields
    stops_on_http_failures
    rejects_unsuccessful_or_malformed_api_responses
    keeps_credentials_out_of_arguments_and_logs
    uses_bounded_requests_without_redirects
    reports_test_failure_location
)

# Each test gets its own process: a failed assertion stops that test immediately.
if [[ $# -eq 1 ]]; then
    test_name=$1
    trap 'printf "FAIL %s at %s:%s\n" "$test_name" "${BASH_SOURCE[0]}" "$LINENO" >&2' ERR
    setup
    "$1"
    exit
fi

failures=0
for test in "${TESTS[@]}"; do
    if bash "${BASH_SOURCE[0]}" "$test"; then
        printf 'PASS %s\n' "$test"
    else
        printf 'FAIL %s\n' "$test" >&2
        failures=$((failures + 1))
    fi
done
printf '%s tests, %s failures\n' "${#TESTS[@]}" "$failures"
[[ $failures -eq 0 ]]
