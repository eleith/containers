# 🛠 Building

Build from the repo root:

```bash
docker build -t porkbun-ddns ./porkbun-ddns
docker build -t hledger ./hledger
```

Check the container README and Dockerfile for build options

## Dockerfiles

- Prefer supported Alpine releases
- Combine related `RUN` commands for smaller image sizes
- Use `ENTRYPOINT` for dedicated commands. Keep toolchain images usable by CI shells.
- Run as non-root where practical. Document required mounts and capabilities.

## Shell scripts

- Keep functions focused and `main` easy to follow.
- Use `set -euo pipefail` in Bash scripts.
- Use `jq` for JSON and `awk`, `sed`, or `grep` for text.
- Give network requests timeouts and return nonzero on failures.

## Adding a container

1. Add its directory, `Dockerfile`, scripts, and README with usage and arguments.
2. Add [tests and PR checks](testing.md) in GitHub Actions and Woodpecker.
3. Add [release workflows and cleanup registration](releases.md).
4. Add it to [What's inside?](../README.md).
