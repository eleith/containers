FROM alpine:3.23

RUN apk add --no-cache bash ca-certificates curl jq

COPY --chmod=755 update.sh /usr/local/bin/porkbun-ddns

USER 65534:65534

ENTRYPOINT ["/usr/local/bin/porkbun-ddns"]
