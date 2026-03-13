FROM alpine:3.21

RUN apk add --no-cache \
    wireguard-tools \
    curl \
    iproute2 \
    ip6tables \
    openresolv \
    bash && \
    sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' /usr/bin/wg-quick

WORKDIR /app

COPY verify-wg.sh /app/verify-wg.sh
RUN chmod +x /app/verify-wg.sh

ENTRYPOINT ["/app/verify-wg.sh"]
