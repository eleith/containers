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

# Request bodies arrive on stdin so credentials never enter curl's arguments.
api_request() {
    local path=$1 response
    response=$(curl --disable --silent --show-error --fail \
        --connect-timeout 10 --max-time 30 \
        --header 'Content-Type: application/json' \
        --data-binary @- "${API_URL}${path}") || fail "Request failed: $path"

    # Do not print raw API errors: they could contain sensitive information.
    jq -ces 'select(length == 1) | .[0] |
        select(type == "object" and .status == "SUCCESS")' \
        <<< "$response" 2>/dev/null || fail "Unsuccessful or malformed API response: $path"
}

main() {
    local dry_run=false
    if [[ ${1:-} == --dry-run ]]; then
        dry_run=true
        shift
    fi
    [[ $# -eq 2 ]] || fail 'Usage: porkbun-ddns [--dry-run] <domain> <name> (use "" for the domain apex)'
    local domain=${1,,} name=${2,,} target
    valid_hostname "$domain" || fail 'Invalid domain; use a DNS name without a trailing dot.'
    target=$domain
    if [[ -n $name ]]; then
        valid_hostname "$name" || fail 'Invalid record name; use a relative DNS name.'
        target="$name.$domain"
    fi
    valid_hostname "$target" || fail 'The full record name is too long.'

    local auth
    auth=$(jq -ces 'select(length == 1) | .[0] | {apikey, secretapikey} |
        select(all(.[]; type == "string" and length > 0))' \
        "$CREDENTIALS_FILE" 2>/dev/null) || fail "Expected apikey and secretapikey in $CREDENTIALS_FILE"

    local ping public_ip
    ping=$(printf '%s\n' "$auth" | api_request /ping)
    public_ip=$(jq -er '.yourIp | select(type == "string") |
        select(test("^(0|[1-9][0-9]{0,2})(\\.(0|[1-9][0-9]{0,2})){3}$")) |
        select(split(".") | all(.[]; tonumber <= 255))' \
        <<< "$ping" 2>/dev/null) || fail 'Porkbun did not return a valid IPv4 address.'

    local path response records count record record_id current_ip ttl
    path="/dns/retrieveByNameType/$domain/A"
    [[ -z $name ]] || path+="/$name"
    response=$(printf '%s\n' "$auth" | api_request "$path")
    records=$(jq -ce '.records | select(type == "array")' <<< "$response" 2>/dev/null) \
        || fail 'Porkbun did not return a DNS record list.'
    count=$(jq 'length' <<< "$records")
    [[ $count -eq 1 ]] || fail "Expected exactly one existing A record for $target; found $count. Refusing to update."

    record=$(jq -ce --arg target "$target" '.[0] |
        select(.type == "A") |
        select(.name | type == "string") |
        select((.name | ascii_downcase | rtrimstr(".")) == $target) |
        select(.id | type == "string" and test("^[0-9]+$")) |
        select(.content | type == "string" and length > 0)' \
        <<< "$records" 2>/dev/null) || fail 'Porkbun returned an invalid or unexpected DNS record.'
    record_id=$(jq -r '.id' <<< "$record")
    current_ip=$(jq -r '.content' <<< "$record")
    ttl=$(jq -er '.ttl | tonumber | select(. > 0 and . == floor)' \
        <<< "$record" 2>/dev/null) || fail 'Porkbun returned an invalid record TTL.'

    if [[ $current_ip == "$public_ip" ]]; then
        printf 'Unchanged: %s A %s\n' "$target" "$public_ip"
        return
    fi

    if [[ $dry_run == true ]]; then
        printf 'Dry run: would update %s A %s -> %s\n' "$target" "$current_ip" "$public_ip"
        return
    fi

    # Send the existing name/type/TTL explicitly; edit only this record's ID.
    jq -c --arg name "$name" --arg public_ip "$public_ip" --argjson ttl "$ttl" \
        '. + {name: $name, type: "A", content: $public_ip, ttl: $ttl}' <<< "$auth" \
        | api_request "/dns/edit/$domain/$record_id" > /dev/null
    printf 'Updated: %s A %s -> %s\n' "$target" "$current_ip" "$public_ip"
}

# Allow the same entry point to be exercised with mocked HTTP calls in tests.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
