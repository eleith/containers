# 🔍 DANE Verify

a small script that verifies TLSA records against live certificates via SMTP STARTTLS.

## 🤔 How it works

The `check.sh` script does the heavy lifting:

1. Fetches TLSA records for a target host.
2. Checks for `ad` (Authentic Data) flag via DNSSEC.
3. Connects to the host via SMTP STARTTLS.
4. Compares the live cert (or public key) hash with what's in your DNS.

## 🛠 Usage

### Docker

You can run it manually to check a domain:

```bash
docker run --rm \
  ghcr.io/eleith/containers-dane-verify \
  mail.example.com:25 -r 8.8.8.8
```

*Arguments:*

* `hostname[:port]`: The mail server to check. Port defaults to 25.
* `-r resolver` (Optional): The DNS resolver to use (e.g., 1.1.1.1).

## 📦 Tech Stack

* **Base:** Alpine Linux
* **Tools:** `openssl`, `bind-tools` (dig), `awk`, `bash`
