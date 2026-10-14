# Upstream's linux-x64 binary is statically linked, so it runs on Alpine.
FROM alpine:3.24.2 AS build

ARG HLEDGER_VERSION=1.99.5
ARG HLEDGER_SHA256=62f4ceb82239f63e88a88a785faa9a23c61d9d611def7c0fed19140a5f5cdbf6

ENV LANG=C.UTF-8

RUN test "$(uname -m)" = x86_64 \
    && apk add --no-cache ca-certificates curl \
    && curl -fsSL -o /tmp/hledger.tar.gz \
        "https://github.com/hledgerorg/hledger/releases/download/${HLEDGER_VERSION}/hledger-linux-x64.tar.gz" \
    && echo "${HLEDGER_SHA256}  /tmp/hledger.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/hledger.tar.gz -C /usr/local/bin hledger \
    && chmod +x /usr/local/bin/hledger \
    && rm /tmp/hledger.tar.gz \
    && hledger --version | grep -F "hledger ${HLEDGER_VERSION},"

FROM alpine:3.24.2

RUN apk add --no-cache ca-certificates

ENV LANG=C.UTF-8

COPY --from=build /usr/local/bin/hledger /usr/local/bin/hledger

# No fixed entrypoint: CI runners can execute shell scripts normally.
CMD ["hledger", "--help"]
