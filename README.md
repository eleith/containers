# 📦 Containers

This repo is a collection of small, focused Docker containers for use in crons,
ci and cd.

## 🛠 What's inside?

- [**dane-verify**](./dane-verify): A specialized tool to monitor a domain's
  DNSSEC and TLSA records
- [**nvim**](./nvim): Neovim, `lua-language-server`, and `stylua` for
  linting, formatting, and testing Lua code and nvim plugins
- [**ssh**](./ssh): A lightweight alpine image with an SSH client
- [**wg-verify**](./wg-verify): Verifies a WireGuard VPN tunnel by checking
  handshake status and testing connectivity to an internal URL
- [**yq**](./yq): A lightweight image with Mike Farah's `yq` and `bash`
- [**playwright**](./playwright): playwright + node 26 + Temporal

## 🚀 Quick Start

Each container lives in its own directory with its own `Dockerfile`. To build them:

```bash
docker build -t dane-verify ./dane-verify
docker build -t nvim ./nvim
docker build -t ssh ./ssh
docker build -t wg-verify ./wg-verify
docker build -t yq ./yq
```
