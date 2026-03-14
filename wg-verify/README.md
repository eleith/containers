# wg-verify

Verifies a WireGuard VPN tunnel by bringing up the interface, checking for a
successful handshake, and testing connectivity to a URL through the tunnel.

## Usage

Mount your `wg0.conf` and provide the target URL:

```bash
docker run --rm \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -v /path/to/your/wg0.conf:/etc/wireguard/wg0.conf \
  wg-verify https://internal-service.example.com
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-v` | Verbose output (show `wg-quick` commands and source IP) | off |
| `-s` | Expected HTTP status code | `200` |
| `-t` | Timeout in seconds, applied separately to handshake and HTTP request | `10` |

Example with verbose output and a custom expected status:

```bash
docker run --rm \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -v /path/to/your/wg0.conf:/etc/wireguard/wg0.conf \
  wg-verify -v -s 302 https://internal-service.example.com
```

### DNS

The container uses Docker's DNS resolver during startup to resolve the
WireGuard endpoint for the initial handshake. Once the tunnel is up, it
switches to the DNS server from your `wg0.conf` (`DNS` setting), matching how
real WireGuard clients behave.

To override the initial DNS resolver (e.g. if Docker's default DNS cannot
resolve your WireGuard endpoint), use Docker's `--dns` flag:

```bash
docker run --rm \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --dns 8.8.8.8 \
  -v /path/to/your/wg0.conf:/etc/wireguard/wg0.conf \
  wg-verify https://internal-service.example.com
```

## Requirements

- `--cap-add=NET_ADMIN` — required for WireGuard to create the tunnel interface
- `--sysctl net.ipv4.conf.all.src_valid_mark=1` — required for WireGuard routing policy rules
- A valid WireGuard client config mounted at `/etc/wireguard/wg0.conf`
