# 📟 SSH Client

This container is a minimal SSH client on Alpine, perfect for those quick CI/CD
tasks that need to SSH into a server to deploy or run a command.

## 🛠 Usage

### Docker

Running a quick command remotely:

```bash
docker run --rm \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
  ghcr.io/eleith/containers-ssh \
  ssh -o StrictHostKeyChecking=no user@example.com "ls -la"
```

## 📦 Tech Stack

- **Base:** Alpine Linux
- **Tools:** `openssh-client`
