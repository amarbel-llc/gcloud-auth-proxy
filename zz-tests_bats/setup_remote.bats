#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  export output
}

teardown() {
  teardown_test_home
}

function setup_remote_without_host_runs_locally { # @test
  run gcloud-auth-proxy setup-remote
  assert_success
  assert_output --partial "Local host configured."
}

function setup_remote_creates_credential_helper { # @test
  run gcloud-auth-proxy setup-remote
  assert_success
  [[ -f "$HOME/.config/gcloud/credential_helper.sh" ]]
  [[ -x "$HOME/.config/gcloud/credential_helper.sh" ]]
}

function setup_remote_credential_helper_uses_socket { # @test
  run gcloud-auth-proxy setup-remote
  assert_success
  run cat "$HOME/.config/gcloud/credential_helper.sh"
  assert_output --partial "/tmp/gcloud-auth-proxy.sock"
}

function setup_remote_is_idempotent { # @test
  run gcloud-auth-proxy setup-remote
  assert_success
  run gcloud-auth-proxy setup-remote
  assert_success
  [[ -f "$HOME/.config/gcloud/credential_helper.sh" ]]
}
