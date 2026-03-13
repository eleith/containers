FROM alpine:3.21

RUN apk add --no-cache \
    wireguard-tools \
    curl \
    iproute2 \
    bash

WORKDIR /app

COPY verify-wg.sh /app/verify-wg.sh
RUN chmod +x /app/verify-wg.sh

ENTRYPOINT ["/app/verify-wg.sh"]
