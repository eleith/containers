# 📦 Containers

This repo is a collection of small, focused Docker containers for use in crons,
ci and cd.

## 🧰 What's inside?

- [**dane-verify**](./dane-verify): A specialized tool to monitor a domain's
  DNSSEC and TLSA records
- [**porkbun-ddns**](./porkbun-ddns): Updates one existing Porkbun A record to
  the host's public IPv4 address
- [**hledger**](./hledger): hledger 1.99.5 (2.0 preview) for journal validation
  and reporting in CI
- [**nvim**](./nvim): Neovim, `lua-language-server`, and `stylua` for
  linting, formatting, and testing Lua code and nvim plugins
- [**ssh**](./ssh): A lightweight alpine image with an SSH client
- [**wg-verify**](./wg-verify): Verifies a WireGuard VPN tunnel by checking
  handshake status and testing connectivity to an internal URL
- [**yq**](./yq): A lightweight image with Mike Farah's `yq` and `bash`
- [**playwright**](./playwright): playwright + node 26 + Temporal

## 📚 Docs

- [Building](docs/building.md)
- [Testing](docs/testing.md)
- [Releases](docs/releases.md)
- [Secrets](docs/secrets.md)
