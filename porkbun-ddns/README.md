# 🐷 Porkbun DDNS

Updates one existing Porkbun A record to the host's public IPv4 address.
Runs once and exits; scheduling is handled externally.

## 🛠 Usage

Enable API access for your domain and store your credentials in a protected JSON
file outside this repository:

```json
{
  "apikey": "YOUR_API_KEY",
  "secretapikey": "YOUR_SECRET_API_KEY"
}
```

Mount the file read-only to update `home.example.com`:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src=/path/to/porkbun.json,dst=/run/secrets/porkbun.json,readonly \
  ghcr.io/eleith/containers-porkbun-ddns:1.0.0 example.com home
```

`--user` lets the container read a credentials file protected for your host user.

### Arguments

| Argument | Description |
|----------|-------------|
| `--dry-run` | Optional; place before the domain to report changes without updating DNS. Still calls Porkbun to check the IP and record. |
| `domain` | Porkbun zone, such as `example.com` or `example.co.uk`. |
| `name` | Relative record name, such as `home` or `services.home`; use `""` for the zone apex. |

Requires exactly one existing A record; never creates records. Skips unchanged
addresses and preserves the TTL. Errors exit nonzero. Use ASCII/punycode names
without trailing dots; wildcard names are not supported.

## 🏷 Tags

Release tags use `porkbun-ddns/vX.Y.Z` and publish `X`, `X.Y`, and `X.Y.Z`.
Pin a full version or digest; there is no `latest`. Pushes to `main` build and
test without publishing.

## ✅ Tests

Local checks use mocked HTTP calls; no real credentials are needed:

```bash
shellcheck porkbun-ddns/update.sh porkbun-ddns/tests/update_test.sh
bash porkbun-ddns/tests/update_test.sh
```

## 📦 Tech Stack

- **Base:** Alpine Linux
- **Tools:** Bash, curl, jq
