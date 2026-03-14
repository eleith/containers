# wg-verify

Verifies a WireGuard VPN tunnel by bringing up the interface, checking for a
successful handshake, and testing connectivity to a URL.

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
| `-v` | Verbose output (show `wg-quick` commands) | off |
| `-s` | Expected HTTP status code | `200` |

Example with verbose output and a custom expected status:

```bash
docker run --rm \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -v /path/to/your/wg0.conf:/etc/wireguard/wg0.conf \
  wg-verify -v -s 302 https://internal-service.example.com
```

### DNS

The container uses Docker's DNS to resolve the WireGuard endpoint during
startup. Once the tunnel is up, it switches to the DNS server specified in your
`wg0.conf` (the `DNS` setting), matching how real WireGuard clients behave.

## Requirements

- `--cap-add=NET_ADMIN` is required for WireGuard to create the tunnel interface
- `--sysctl net.ipv4.conf.all.src_valid_mark=1` is required for WireGuard's routing policy rules
- A valid WireGuard client config must be mounted at `/etc/wireguard/wg0.conf`
