# 🌙 nvim

A Debian-based container with Neovim, `lua-language-server`, and `stylua` for
linting, type-checking, formatting, and testing Neovim plugins.

Perfect for CI/CD steps where you want a pinned Neovim + Lua toolchain ready to
go without downloading release tarballs on every run.

There is no standalone `lua`: plugins run on Neovim's built-in LuaJIT, so tests
run through `nvim --headless` (or `nvim -l`), and `stylua` and
`lua-language-server` don't need one.

## 🛠 Usage

### Docker

#### Check formatting
Mount your current directory to the container and run `stylua`:

```bash
docker run --rm -v "${PWD}":/workdir -w /workdir ghcr.io/eleith/containers-nvim:0.12.1-luals3.19.1-stylua2.5.2 stylua --check .
```

#### Type-check with lua-language-server

```bash
docker run --rm -v "${PWD}":/workdir -w /workdir ghcr.io/eleith/containers-nvim:0.12.1-luals3.19.1-stylua2.5.2 lua-language-server --check .
```

Set `"runtime.version": "LuaJIT"` in your `.luarc.json` so it checks against
what Neovim actually runs, and declare test globals (`describe`, `MiniTest`, …)
there too.

#### Run headless Neovim

```bash
docker run --rm -v "${PWD}":/workdir -w /workdir ghcr.io/eleith/containers-nvim:0.12.1-luals3.19.1-stylua2.5.2 nvim --headless -c 'lua print(vim.version())' -c 'qa'
```

### 🧪 Tests

Test frameworks are not baked in. Clone the one you use at run time (`git` is
installed) and put it on the runtimepath.

#### plenary

```bash
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim /tmp/plenary
nvim --headless --noplugin -u NONE \
  -c "set rtp+=.,/tmp/plenary" -c "runtime plugin/plenary.vim" \
  -c "PlenaryBustedDirectory tests {minimal_init = 'NONE', init = 'NONE'}"
```

#### mini.test

```bash
git clone --depth 1 https://github.com/echasnovski/mini.nvim /tmp/mini
nvim --headless --noplugin -u NONE \
  -c "set rtp+=.,/tmp/mini" -c "lua require('mini.test').setup()" \
  -c "lua MiniTest.run()" -c "qa!"
```

### CI/CD (Woodpecker/GitHub Actions)

Since the image has `git` and `make` installed, you can use it in your CI
pipeline steps to run your existing test and lint targets:

#### GitHub Actions

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/eleith/containers-nvim:0.12.1-luals3.19.1-stylua2.5.2
    steps:
      - uses: actions/checkout@v4
      - run: stylua --check .
      - run: lua-language-server --check .
```

## 🏷 Tags

Releases are tagged `nvim/vX.Y.Z`, which publishes the semver tags plus a
descriptive one naming what is inside:

```
1  1.0  1.0.0  0.12.1-luals3.19.1-stylua2.5.2
```

The descriptive tag is derived from this `Dockerfile`'s build args at build
time, so it cannot drift. There is **no `latest`**: pin the descriptive tag (or
a semver tag) so a tool bump can never arrive unannounced. Pushes to `main`
build the image without publishing it.

## ⚙️ Build Args

Tool versions are pinned via build args:

| Arg              | Default  |
| ---------------- | -------- |
| `NVIM_VERSION`   | `0.12.1` |
| `LUALS_VERSION`  | `3.19.1` |
| `STYLUA_VERSION` | `2.5.2`  |

To bump a tool, change its default here and tag a release. Overriding with
`--build-arg` only affects local builds; CI tags are read from the defaults.

```bash
docker build --build-arg NVIM_VERSION=0.12.1 -t nvim ./nvim
```

## 📦 Tech Stack

- **Base:** Debian 13 (slim)
- **Tools:** `nvim` (with LuaJIT), `lua-language-server`, `stylua`, `git`, `make`, `curl`
- **Arch:** `x86_64` only (release binaries are downloaded for `linux-x86_64`)
