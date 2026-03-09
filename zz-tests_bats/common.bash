bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-assert-additions
bats_load_library bats-island

FAKE_TOKEN="fake-gcloud-token-for-testing"
export FAKE_TOKEN

setup_fake_gcloud() {
  local fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/gcloud" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" && "${2:-}" == "print-access-token" ]]; then
  echo "fake-gcloud-token-for-testing"
  exit 0
fi
echo "fake gcloud: unknown command: $*" >&2
exit 1
SCRIPT
  chmod +x "$fake_bin/gcloud"
  export PATH="$fake_bin:$PATH"
}

start_proxy() {
  export GCLOUD_AUTH_PROXY_SOCKET="$BATS_TEST_TMPDIR/proxy.sock"
  gcloud-auth-proxy serve &
  PROXY_PID=$!

  local retries=50
  while [[ ! -S "$GCLOUD_AUTH_PROXY_SOCKET" ]]; do
    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
      echo "proxy process died" >&2
      return 1
    fi
    retries=$((retries - 1))
    if [[ $retries -le 0 ]]; then
      echo "timed out waiting for socket" >&2
      return 1
    fi
    sleep 0.1
  done
}

stop_proxy() {
  if [[ -n "${PROXY_PID:-}" ]]; then
    kill "$PROXY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
}
