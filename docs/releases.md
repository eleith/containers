# 🏷 Releases

| Event | Result |
|-------|--------|
| Pull request | Existing checks |
| Push to `main` | Build and publish `latest` for updated containers |
| Release tag | Build and publish version tags |

`latest` follows `main`. Release builds leave it unchanged.

## Tags

Release tags use `<container>/vX.Y.Z`. Choose an unused version and tag `main`:

```bash
tag=porkbun-ddns/v0.0.3

git switch main
git pull --ff-only
git tag "$tag"
git push origin "$tag"
```

Release pipelines publish `X`, `X.Y`, and `X.Y.Z` image tags.
Neovim and Playwright also publish their version-specific toolchain tags.

## Registries

- Public: `ghcr.io/eleith/containers-<name>`
- Private: `git.eleith.com/eleith.private/<name>`

GitHub Actions and Woodpecker publish matching release tags.

## Adding release workflows

- Add `.github/workflows/build-<name>.yml` and `.woodpecker/build-<name>.yml`.
- Keep version extraction and publishing behavior aligned in both workflows.
- In GitHub Actions, disable automatic `latest` with `flavor: latest=false` and
  enable the explicit `latest` tag only for `refs/heads/main`.
- In Woodpecker, use `tags: latest` for main builds and a version-only `.tags`
  file for releases.
