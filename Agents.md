# 🤖 Hello, Fellow Agent!

Welcome to the utility belt. To help you help us, here's some context and rules for making updates here.

## 📜 Principles

- **Alpine First:** Prefer Alpine where suitable. Keep images small and focused; document why another base is needed.
- **Security:** Do not hardcode credentials. Prefer read-only mounted secrets; keep credentials out of logs and command arguments.
- **Accuracy:** Scripts like `check.sh` are precise. When updating them, ensure you maintain the core DANE/TLSA logic correctly.

## 🛠 Working with the Codebase

### Dockerfiles
- Use supported stable base-image versions and install only the dependencies the tool needs.
- Minimize layers by combining `RUN` commands where it makes sense.
- Use `ENTRYPOINT` for main commands in specialized containers like `dane-verify`.

### Scripts
- Bash is fine, but keep it readable. Use `set -e` for safety.
- Use `jq` for JSON; `awk`, `sed`, and `grep` are useful for text output from tools like `dig` and `openssl`.
- Bound network requests with timeouts and return nonzero on failures.

### CI/CD
- We use both GitHub Actions and [Woodpecker CI](https://woodpecker-ci.org/). Keep their build, test, and publishing behavior aligned.
- Prefer the newer `hledger` and `porkbun-ddns` workflows as examples; older workflows may use different publishing conventions.

## ✅ New Container Checklist

- **Purpose:** One clear command contract. Keep scheduling outside one-shot tools.
- **Image:** Minimal supported base, documented exceptions, and only necessary dependencies.
- **Privileges:** Run as non-root where practical. Document required users, mounts, and capabilities.
- **Tests:** Run lint and offline tests before building in both CI systems. Make failures easy to locate.
- **Releases:** For new images, build `main` without publishing and publish versioned release tags, not `latest`. Document tag names, show pinned usage examples, and register the package in `.github/workflows/cleanup.yml`.
- **Docs:** Brief purpose, working usage example, arguments, and important runtime requirements. No shared framework is required.

## ✅ How to Test

Run each container's documented local checks. For example:

```bash
shellcheck porkbun-ddns/update.sh porkbun-ddns/tests/update_test.sh
bash porkbun-ddns/tests/update_test.sh
```

The user handles Docker builds and runs. Provide commands when needed, but do not execute Docker commands. Live API checks require explicit user approval.

## 🤝 Need Help?

If something is unclear, just ask the user! We're all in this together.
