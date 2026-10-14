# 📒 hledger

An Alpine-based, amd64-only image with **hledger 1.99.5** (2.0 preview 5).
Only the CLI is installed: no `hledger-ui` or `hledger-web`.

Use it in CI to validate journals, enforce declared accounts/commodities, and
produce reports. The upstream static binary is pinned and SHA-256 verified.
There is no fixed entrypoint, so CI runners can execute shell scripts normally.

## 🛠 Usage

Mount your journal directory, including any files referenced by `include`:

```bash
docker run --rm -v "${PWD}":/workdir -w /workdir \
  ghcr.io/eleith/containers-hledger:1.99.5 \
  hledger -f main.journal check
```

Enforce account and commodity declarations (add `account` and `commodity`
directives to your journal first):

```bash
hledger -f main.journal check accounts commodities
```

Generate a CSV report on the host:

```bash
docker run --rm -v "${PWD}":/workdir -w /workdir \
  ghcr.io/eleith/containers-hledger:1.99.5 \
  hledger -f main.journal balance -O csv > balance.csv
```

For files written inside the mount, use `--user "$(id -u):$(id -g)"` to avoid
root-owned output.

### Woodpecker

```yaml
steps:
  check-journal:
    image: ghcr.io/eleith/containers-hledger:1.99.5
    commands:
      - hledger -f main.journal check accounts commodities
      - hledger -f main.journal balance -O csv > balance.csv
```

The private registry image is `git.eleith.com/eleith.private/hledger:1.99.5`.

## 🏷 Tags

Release tags use `hledger/vX.Y.Z`, matching the packaged hledger version.
For example, `hledger/v1.99.5` publishes `1`, `1.99`, and `1.99.5`.
There is no extra tool-prefixed tag and no `latest`; pin the full version tag
or image digest for CI.

Pushes to `main` build without publishing. Release tags publish via
GitHub Actions and Woodpecker, like `nvim`.

## ⚙️ Build

```bash
docker build --platform linux/amd64 -t hledger ./hledger
docker run --rm hledger hledger --version
```

The build verifies the archive's SHA-256 checksum and checks `hledger --version`.

| Build arg        | Default                                                            |
| ---------------- | ------------------------------------------------------------------ |
| `HLEDGER_VERSION` | `1.99.5`                                                           |
| `HLEDGER_SHA256`  | `62f4ceb82239f63e88a88a785faa9a23c61d9d611def7c0fed19140a5f5cdbf6` |

To upgrade to another preview or 2.0, update **both** defaults using that
release's Linux x64 archive and checksum, then tag the matching release
(e.g. `hledger/v2.0.0`). Local `--build-arg` overrides do not affect CI's tags.

**Base:** Alpine 3.24.2. **Architecture:** Linux amd64 only.
The image includes CA certificates and Alpine's `/bin/sh`; no Git, Make, or
Bash toolchain is bundled.
