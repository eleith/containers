#!/bin/bash
set -euo pipefail

API_URL=https://api-ipv4.porkbun.com/api/json/v3
CREDENTIALS_FILE=/run/secrets/porkbun.json

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

valid_hostname() {
    local label='[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?'
    [[ ${#1} -le 253 && $1 =~ ^$label(\.$label)*$ ]]
}

read_credentials() {
    [[ -e $CREDENTIALS_FILE ]] || fail \
        "Credentials file not found or inaccessible: $CREDENTIALS_FILE." \
        'Check the Docker-host bind mount path and directory permissions.'
    [[ ! -d $CREDENTIALS_FILE ]] || fail \
        "Credentials path is a directory: $CREDENTIALS_FILE." \
        'Mount a JSON file instead.'

    local contents
    contents=$(cat "$CREDENTIALS_FILE" 2>/dev/null) || fail \
        "Cannot read credentials file $CREDENTIALS_FILE as UID:GID $(id -u):$(id -g)." \
        "Check file permissions and the container's --user."

    local documents
    documents=$(jq -cs '.' <<< "$contents" 2>/dev/null) || fail \
        "Invalid JSON in credentials file $CREDENTIALS_FILE." \
        'Fix the JSON syntax.'

    local auth
    auth=$(jq -ce '
        select(length == 1)
        | .[0]
        | select(type == "object")
        | {apikey, secretapikey}
        | select(all(.[]; type == "string" and length > 0))
    ' <<< "$documents" 2>/dev/null) || fail \
        "Credentials file $CREDENTIALS_FILE must contain one JSON object" \
        'with non-empty string fields apikey and secretapikey.'

    jq -e 'all(.[]; test("\\s") | not)' <<< "$auth" > /dev/null || fail \
        "apikey or secretapikey contains whitespace in $CREDENTIALS_FILE." \
        'Re-copy the keys without whitespace.'
    printf '%s\n' "$auth"
}

# Request bodies arrive on stdin so credentials never enter curl's arguments.
api_request() {
    local path=$1
    local curl_output
    curl_output=$(curl --disable --silent --show-error \
        --connect-timeout 10 --max-time 30 \
        --header 'Content-Type: application/json' \
        --write-out '\n%{http_code}' \
        --data-binary @- "${API_URL}${path}") || fail \
        "Network request failed: $path." \
        'Check connectivity, DNS, and TLS.'

    local http_status=${curl_output##*$'\n'}
    local response_body=${curl_output%$'\n'*}

    # Keep error bodies for classification, but never log raw responses or keys.
    local api_response
    api_response=$(jq -ces '
        select(length == 1)
        | .[0]
        | select(type == "object")
        | select(.status | type == "string")
    ' <<< "$response_body" 2>/dev/null) || api_response=''

    if [[ $http_status == 401 ]] || jq -e '
        .credentialsValid == false
        or any(.message | strings; test("invalid (secret )?api key"; "i"))
    ' <<< "$api_response" > /dev/null 2>&1; then
        fail \
            "Porkbun rejected the API credentials: $path (HTTP $http_status)." \
            'Check that apikey and secretapikey are a matching, valid pair.'
    fi
    if [[ $http_status == 403 ]]; then
        fail \
            "Porkbun denied API access: $path (HTTP 403)." \
            "Check the domain's API Access setting and the key's permissions" \
            'and domain/IP restrictions.'
    fi
    [[ $http_status == 2[0-9][0-9] ]] \
        || fail "Porkbun request failed: $path (HTTP $http_status)."
    [[ -n $api_response ]] \
        || fail "Malformed API response: $path (HTTP $http_status)."
    jq -e '.status == "SUCCESS"' <<< "$api_response" > /dev/null \
        || fail "Porkbun rejected the request: $path (HTTP $http_status)."
    printf '%s\n' "$api_response"
}

get_public_ipv4() {
    local ping
    ping=$(api_request /ping) || return 1

    jq -er '
        .yourIp
        | select(type == "string")
        | select(test("^(0|[1-9][0-9]{0,2})(\\.(0|[1-9][0-9]{0,2})){3}$"))
        | select(split(".") | all(.[]; tonumber <= 255))
    ' <<< "$ping" 2>/dev/null || fail 'Porkbun did not return a valid IPv4 address.'
}

get_single_a_record() {
    local domain=$1 name=$2 target=$3
    local path="/dns/retrieveByNameType/$domain/A"
    if [[ -n $name ]]; then
        path+="/$name"
    fi

    local response
    response=$(api_request "$path") || return 1

    local records
    records=$(jq -ce '.records | select(type == "array")' <<< "$response" 2>/dev/null) \
        || fail 'Porkbun did not return a DNS record list.'

    local count
    count=$(jq 'length' <<< "$records")
    [[ $count -eq 1 ]] || fail \
        "Expected exactly one existing A record for $target; found $count." \
        'Refusing to update.'

    local record
    record=$(jq -ce --arg target "$target" '
        .[0]
        | select(.type == "A")
        | select(.name | type == "string")
        | select((.name | ascii_downcase | rtrimstr(".")) == $target)
        | select(.id | type == "string" and test("^[0-9]+$"))
        | select(.content | type == "string" and length > 0)
    ' <<< "$records" 2>/dev/null) || fail \
        'Porkbun returned an invalid or unexpected DNS record.'

    jq -e '.ttl | tonumber | select(. > 0 and . == floor)' \
        <<< "$record" > /dev/null 2>&1 || fail 'Porkbun returned an invalid record TTL.'
    printf '%s\n' "$record"
}

update_existing_record() {
    local domain=$1 name=$2 record=$3 public_ip=$4
    local record_id ttl
    record_id=$(jq -r '.id' <<< "$record")
    ttl=$(jq '.ttl | tonumber' <<< "$record")

    jq -c \
        --arg name "$name" \
        --arg public_ip "$public_ip" \
        --argjson ttl "$ttl" '
        . + {
            name: $name,
            type: "A",
            content: $public_ip,
            ttl: $ttl
        }
    ' | api_request "/dns/edit/$domain/$record_id" > /dev/null
}

main() {
    local dry_run=false
    if [[ ${1:-} == --dry-run ]]; then
        dry_run=true
        shift
    fi
    [[ $# -eq 2 ]] || fail \
        'Usage: porkbun-ddns [--dry-run] <domain> <name>' \
        '(use "" for the domain apex)'
    local domain=${1,,} name=${2,,} target
    valid_hostname "$domain" || fail 'Invalid domain; use a DNS name without a trailing dot.'
    target=$domain
    if [[ -n $name ]]; then
        valid_hostname "$name" || fail 'Invalid record name; use a relative DNS name.'
        target="$name.$domain"
    fi
    valid_hostname "$target" || fail 'The full record name is too long.'

    local auth
    auth=$(read_credentials)

    local public_ip
    public_ip=$(printf '%s\n' "$auth" | get_public_ipv4)

    local record current_ip
    record=$(printf '%s\n' "$auth" | get_single_a_record "$domain" "$name" "$target")
    current_ip=$(jq -r '.content' <<< "$record")

    if [[ $current_ip == "$public_ip" ]]; then
        printf 'Unchanged: %s A %s\n' "$target" "$public_ip"
        return
    fi

    if [[ $dry_run == true ]]; then
        printf 'Dry run: would update %s A %s -> %s\n' "$target" "$current_ip" "$public_ip"
        return
    fi

    printf '%s\n' "$auth" | update_existing_record "$domain" "$name" "$record" "$public_ip"
    printf 'Updated: %s A %s -> %s\n' "$target" "$current_ip" "$public_ip"
}

# Allow the same entry point to be exercised with mocked HTTP calls in tests.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
