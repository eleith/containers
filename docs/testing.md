# ✅ Testing

## Local checks

Install Bash, jq, ShellCheck, and Bats to run the current suites:

```bash
shellcheck porkbun-ddns/update.sh porkbun-ddns/tests/update_test.sh
bash porkbun-ddns/tests/update_test.sh
bats dane-verify/tests/
```

These suites mock network calls. Cover validation, failure, and unchanged paths
when changing scripts. Test failures should identify the test and source line.

## CI

Existing checks run on matching pull requests, pushes to `main`, and release tags.
