#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  export output
}

teardown() {
  teardown_test_home
}

function setup_creates_ssh_config_file { # @test
  run gcloud-auth-proxy setup
  assert_success
  [[ -f "$HOME/.config/ssh/config-gcloud-auth-proxy" ]]
}

function setup_config_contains_remote_forward { # @test
  run gcloud-auth-proxy setup
  assert_success
  run cat "$HOME/.config/ssh/config-gcloud-auth-proxy"
  assert_output --partial "RemoteForward /tmp/gcloud-auth-proxy.sock"
}

function setup_config_contains_socket_path { # @test
  run gcloud-auth-proxy setup
  assert_success
  run cat "$HOME/.config/ssh/config-gcloud-auth-proxy"
  assert_output --partial ".local/state/gcloud-auth-proxy/proxy.sock"
}

function setup_prints_include_instruction { # @test
  run gcloud-auth-proxy setup
  assert_success
  assert_output --partial "Include ~/.config/ssh/config-gcloud-auth-proxy"
}

function setup_is_idempotent { # @test
  run gcloud-auth-proxy setup
  assert_success
  run gcloud-auth-proxy setup
  assert_success
  [[ -f "$HOME/.config/ssh/config-gcloud-auth-proxy" ]]
}
