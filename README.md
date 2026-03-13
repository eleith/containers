# 📦 Containers

This repo is a collection of small, focused Docker containers for use in crons,
ci and cd.

## 🛠 What's inside?

- [**dane-verify**](./dane-verify): A specialized tool to monitor a domain's
DNSSEC and TLSA records
- [**ssh**](./ssh): A lightweight alpine image with an SSH client
- [**wg-verify**](./wg-verify): Verifies a WireGuard VPN tunnel by checking
  handshake status and testing connectivity to an internal URL

## 🚀 Quick Start

Each container lives in its own directory with its own `Dockerfile`. To build them:

```bash
docker build -t dane-verify ./dane-verify
docker build -t ssh ./ssh
docker build -t wg-verify ./wg-verify
```
