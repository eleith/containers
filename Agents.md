# 🤖 Hello, Fellow Agent!

Welcome to the utility belt. To help you help us, here's some context and rules for making updates here.

## 📜 Principles

- **Alpine First:** We use Alpine Linux for all our containers. Keep images small and focused.
- **Security:** Do not hardcode credentials. Use secrets or environment variables.
- **Accuracy:** Scripts like `check.sh` are precise. When updating them, ensure you maintain the core DANE/TLSA logic correctly.

## 🛠 Working with the Codebase

### Dockerfiles
- Stick to stable Alpine versions (e.g., `3.20.1` or current LTS).
- Minimize layers by combining `RUN` commands where it makes sense.
- Use `ENTRYPOINT` for main commands in specialized containers like `dane-verify`.

### Scripts
- Bash is fine, but keep it readable. Use `set -e` for safety.
- `awk`, `sed`, and `grep` are our best friends for parsing output from tools like `dig` and `openssl`.

### CI/CD
- We use [Woodpecker CI](https://woodpecker-ci.org/). Check `.woodpecker/*.yml` files for the latest build steps and secrets usage.

## ✅ How to Test

Before you submit a PR, try building the containers:

```bash
docker build -t dane-verify ./dane-verify
docker build -t ssh ./ssh
```

If you can, run a quick check (e.g., against a known-good mail server for DANE):

```bash
docker run --rm dane-verify mail.google.com
```

(Note: Not all servers have TLSA records, so find a target that does!)

## 🤝 Need Help?

If something is unclear, just ask the user! We're all in this together.
