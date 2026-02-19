# 📦 Containers

This repo is a collection of small, focused Docker containers for use in crons,
ci and cd.

## 🛠 What's inside?

- [**dane-verify**](./dane-verify): A specialized tool to monitor a domain's
DNSSEC and TLSA records
- [**ssh**](./ssh): A lightweight alpine image with an SSH client

## 🚀 Quick Start

Each container lives in its own directory with its own `Dockerfile`. To build them:

```bash
docker build -t dane-verify ./dane-verify
docker build -t ssh ./ssh
```
