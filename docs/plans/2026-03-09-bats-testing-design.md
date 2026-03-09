# BATS Conformance Testing + Justfile Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add conformance-style BATS integration tests and a justfile for build/test orchestration.

**Architecture:** Tests exercise the `nix build` artifact as a black box. The real binary is started, real HTTP requests are sent via `curl --unix-socket`, and responses are asserted. Environment is controlled via PATH (fake gcloud) and env vars (socket path) — no mocking internals.

**Tech Stack:** BATS (via batman flake), just, Nix flake devShell, curl, socat

---

### Task 1: Add batman input and devShell to flake.nix

**Files:**
- Modify: `flake.nix`

**Step 1: Add batman flake input and devShell**

Update `flake.nix` to add the `batman` input and a devShell with test tooling:

```nix
{
  description = "Local HTTP proxy providing gcloud access tokens over a Unix socket";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    batman.url = "github:amarbel-llc/batman";
  };

  outputs =
    { nixpkgs, batman, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
    in
    {
      packages = forAllSystems (pkgs: _system: {
        default = pkgs.writeShellApplication {
          name = "gcloud-auth-proxy";
          runtimeInputs = with pkgs; [
            socat
            curl
            google-cloud-sdk
          ];
          text = builtins.readFile ./bin/gcloud-auth-proxy;
        };
      });

      devShells = forAllSystems (pkgs: system: {
        default = pkgs.mkShell {
          packages = [
            pkgs.just
            pkgs.gum
            pkgs.curl
            pkgs.socat
            batman.packages.${system}.default
          ];
        };
      });
    };
}
```

**Step 2: Build to verify flake is valid**

Run: `nix build --show-trace`
Expected: builds successfully, `./result/bin/gcloud-auth-proxy` exists

**Step 3: Commit**

```
feat: add batman input and devShell for BATS testing
```

---

### Task 2: Create root justfile

**Files:**
- Create: `justfile`

**Step 1: Create the justfile**

```just
dir_build := "result"

default: build test

build: build-nix

build-nix:
    nix build --show-trace

test: test-bats

test-bats: build-nix
    just zz-tests_bats/test --bin-dir {{dir_build}}/bin
```

**Step 2: Verify `just build` works**

Run: `just build`
Expected: `nix build` succeeds

**Step 3: Commit**

```
feat: add root justfile with build and test recipes
```

---

### Task 3: Create test infrastructure (common.bash + test justfile)

**Files:**
- Create: `zz-tests_bats/justfile`
- Create: `zz-tests_bats/common.bash`

**Step 1: Create test justfile**

```just
bats_timeout := "10"

test-targets *targets="*.bats":
    BATS_TEST_TIMEOUT="{{bats_timeout}}" \
      bats --jobs {{num_cpus()}} {{targets}}

test-tags *tags:
    BATS_TEST_TIMEOUT="{{bats_timeout}}" \
      bats --jobs {{num_cpus()}} --filter-tags {{tags}} *.bats

test: (test-targets "*.bats")
```

**Step 2: Create common.bash**

```bash
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
```

**Step 3: Commit**

```
feat: add BATS test infrastructure (common.bash, test justfile)
```

---

### Task 4: Write usage.bats

**Files:**
- Create: `zz-tests_bats/usage.bats`

**Step 1: Write tests**

```bash
#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  export output
}

teardown() {
  teardown_test_home
}

function no_arguments_prints_usage { # @test
  run gcloud-auth-proxy
  assert_success
  assert_output --partial "Usage: gcloud-auth-proxy"
}

function help_flag_prints_usage { # @test
  run gcloud-auth-proxy --help
  assert_success
  assert_output --partial "Usage: gcloud-auth-proxy"
}

function short_help_flag_prints_usage { # @test
  run gcloud-auth-proxy -h
  assert_success
  assert_output --partial "Usage: gcloud-auth-proxy"
}

function unknown_command_exits_nonzero { # @test
  run gcloud-auth-proxy bogus-command
  assert_failure
  assert_output --partial "Unknown command: bogus-command"
}
```

**Step 2: Run tests to verify they pass**

Run: `just test`
Expected: all 4 tests pass

**Step 3: Commit**

```
test: add usage conformance tests
```

---

### Task 5: Write serve.bats

**Files:**
- Create: `zz-tests_bats/serve.bats`

**Step 1: Write tests**

```bash
#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  setup_fake_gcloud
  start_proxy
  export output
}

teardown() {
  stop_proxy
  teardown_test_home
}

function health_endpoint_returns_200 { # @test
  run curl -s --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/health
  assert_success
  assert_output "OK"
}

function token_endpoint_returns_fake_token { # @test
  run curl -s --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/token
  assert_success
  assert_output "$FAKE_TOKEN"
}

function unknown_path_returns_not_found { # @test
  run curl -s -o /dev/null -w "%{http_code}" \
    --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/nonexistent
  assert_success
  assert_output "404"
}

function health_endpoint_has_correct_content_type { # @test
  run curl -s -D - --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/health
  assert_success
  assert_output --partial "Content-Type: text/plain"
}
```

**Step 2: Run tests to verify they pass**

Run: `just test`
Expected: all tests pass (usage + serve)

**Step 3: Commit**

```
test: add serve conformance tests
```

---

### Task 6: Write token.bats

**Files:**
- Create: `zz-tests_bats/token.bats`

**Step 1: Write tests**

```bash
#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  setup_fake_gcloud
  export output
}

teardown() {
  stop_proxy
  teardown_test_home
}

function token_fails_when_no_socket { # @test
  export GCLOUD_AUTH_PROXY_SOCKET="$BATS_TEST_TMPDIR/nonexistent.sock"
  run gcloud-auth-proxy token
  assert_failure
  assert_output --partial "proxy socket not found"
}

function token_error_suggests_service_install { # @test
  export GCLOUD_AUTH_PROXY_SOCKET="$BATS_TEST_TMPDIR/nonexistent.sock"
  run gcloud-auth-proxy token
  assert_failure
  assert_output --partial "service-install"
}

function token_prints_token_value { # @test
  start_proxy
  run gcloud-auth-proxy token
  assert_success
  assert_output "$FAKE_TOKEN"
}

function token_export_flag_wraps_in_export { # @test
  start_proxy
  run gcloud-auth-proxy token --export
  assert_success
  assert_output "export CLOUDSDK_AUTH_ACCESS_TOKEN='${FAKE_TOKEN}'"
}
```

**Step 2: Run tests to verify they pass**

Run: `just test`
Expected: all tests pass (usage + serve + token)

**Step 3: Commit**

```
test: add token conformance tests
```

---

### Task 7: Update TODO.md

**Files:**
- Modify: `TODO.md`

**Step 1: Mark BATS task as done**

Remove the `- [ ] Add BATS integration tests` line from TODO.md (it's done).

**Step 2: Commit**

```
chore: mark BATS integration tests as done in TODO
```
