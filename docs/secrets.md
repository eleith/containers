# 🔐 Secrets

## Files

- Store credentials outside the repo and mount them read-only.
- Keep credentials out of images, logs, and command arguments.
- Follow the container README for the required file format and mount destination.

Bind mount source paths refer to the Docker host, including jobs launched by a
scheduler container.

## Users and permissions

Mounted files retain their host ownership and permissions. Check them with:

```bash
stat -c '%u:%g %a' /path/to/credentials.json
```

Set the container's `--user` to a UID:GID that can read the file. For a file owned
by your current host user, use `--user "$(id -u):$(id -g)"`. In Compose, set `user:`
on the service reading the file.

The scheduler and each container it launches have their own runtime user.
Keep credential files restricted to the users that need them.

## CI

Use GitHub Actions secrets and Woodpecker `from_secret` for registry and
notification credentials. Scope them to the steps that need them.
