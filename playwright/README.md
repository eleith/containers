# 🎭 playwright

Microsoft's Playwright image with Node upgraded to 26.

The official `mcr.microsoft.com/playwright` images ship **Node 24** in every variant
(noble, jammy and resolute alike). That is fine for running the Playwright test runner,
but not for serving an app that needs a newer runtime — anything relying on the native
`Temporal` API, for example, throws `Temporal is not defined` on Node 24.

This image keeps the browsers and system libraries from the official image and replaces
Node with 26, so a single container can both serve the app under test and drive the
browser. No browser downloads at pipeline run time.

## 🛠 Usage

### Woodpecker CI

```yaml
steps:
  e2e:
    image: git.eleith.com/eleith.private/playwright:1.61.1-node26
    commands:
      - pnpm install --frozen-lockfile
      - pnpm build:packages
      - cd apps/web && pnpm run test:e2e
```

### Docker

```bash
docker run --rm -v "${PWD}":/app -w /app \
  git.eleith.com/eleith.private/playwright:1.61.1-node26 \
  pnpm run test:e2e
```

## ✅ Verifying a build

```bash
docker build -t playwright:test .
docker run --rm playwright:test node --version              # v26.x
docker run --rm playwright:test ls /ms-playwright           # chromium_headless_shell-1228
docker run --rm playwright:test node -e "Temporal.Now.instant()"
```

The last one is the point of the image: it throws `ReferenceError` on the stock Node 24
base. The Dockerfile's closing `RUN node --version && pnpm --version` fails the build if
the runtime was not replaced, so a green build already covers most of this.

## 🏷 Tags

Releases are tagged `playwright/vX.Y.Z`, which publishes the semver tags plus a
descriptive one naming what is inside:

```
1  1.0  1.0.0  1.61.1-node26
```

The descriptive tag is derived from this `Dockerfile` at build time, so it cannot drift.
There is **no `latest`** — pin `1.61.1-node26` (or a semver tag) so a Playwright or Node
bump can never arrive unannounced. Pushes to `main` build the image without publishing it.

## ⚠️ Version pairing

Playwright refuses to run when the browsers on disk do not match the version of
`@playwright/test` the project installs — it fails with
`Executable doesn't exist at /ms-playwright/chromium_headless_shell-NNNN`.

The base image tag and the project's `@playwright/test` **must be bumped together**:

| image tag | bundled chromium | pair with |
| --- | --- | --- |
| `v1.61.1-noble` | 1228 | `@playwright/test@1.61.1` |

To move to a new Playwright release, change the `FROM` tag here, tag a release, and bump
the dependency in the consuming project in the same change.

## ⚠️ corepack

`pnpm` is baked in via corepack at build time. Setting `COREPACK_HOME` in a pipeline step
points corepack at an empty directory, and it will re-download pnpm on every run — leave
it unset to use the bundled copy.

A project whose `packageManager` field pins a different pnpm version will also fetch that
version at run time. Rebuild with `--build-arg PNPM_VERSION=…` to bake in a different one.

## 📦 Tech Stack

- **Base:** `mcr.microsoft.com/playwright:v1.61.1-noble` (Ubuntu 24.04)
- **Browsers:** chromium, firefox and webkit at `/ms-playwright`
- **Runtime:** Node 26 (nodesource), corepack, pnpm 11.9.0
