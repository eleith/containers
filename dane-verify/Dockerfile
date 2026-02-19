FROM alpine:3.20.1

RUN apk add --no-cache \
    bash \
    openssl \
    bind-tools \
    gawk \
    sed \
    util-linux

WORKDIR /app

COPY check.sh /usr/local/bin/check.sh
RUN chmod +x /usr/local/bin/check.sh

ENTRYPOINT ["/usr/local/bin/check.sh"]
