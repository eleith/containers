# 🧩 yq

A lightweight container containing Mike Farah's `yq` (a command-line YAML, JSON, XML, CSV, TOML, HCL, and properties processor) and `bash`.

Perfect for CI/CD steps where you want `yq` ready to go without installing it on every run.

## 🛠 Usage

### Docker

#### Processing a local file
Mount your current directory to the container and process files:

```bash
docker run --rm -v "${PWD}":/workdir ghcr.io/eleith/containers-yq '.a.b[0].c' file.yaml
```

#### Pipe data via STDIN
Use the `-i` (interactive) flag to pipe data:

```bash
docker run -i --rm ghcr.io/eleith/containers-yq '.this.thing' < myfile.yml
```

### CI/CD (Woodpecker/GitHub Actions)

Since the image has `bash` installed, you can use it in your CI pipeline steps and write scripts or commands:

#### Woodpecker CI

```yaml
steps:
  parse-config:
    image: git.eleith.com/eleith.private/yq:latest
    commands:
      - yq '.database.host' config.yaml
```

#### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Parse config
        uses: docker://ghcr.io/eleith/containers-yq
        with:
          args: .database.host config.yaml
```

## 📦 Tech Stack

- **Base:** Alpine Linux
- **Tools:** `yq` (via `yq-go`), `bash`
